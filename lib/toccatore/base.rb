require 'maremma'
require 'active_support/all'
require 'namae'
require 'gender_detector'

module Toccatore
  class Base
    # load ENV variables from .env file if it exists
    env_file = File.expand_path("../../../.env", __FILE__)
    if File.exist?(env_file)
      require 'dotenv'
      Dotenv.load! env_file
    end

    # load ENV variables from container environment if json file exists
    # see https://github.com/phusion/baseimage-docker#envvar_dumps
    env_json_file = "/etc/container_environment.json"
    if File.size?(env_json_file).to_i > 2
      env_vars = JSON.parse(File.read(env_json_file))
      env_vars.each { |k, v| ENV[k] = v }
    end

    def get_query_url(options={})
      offset = options[:offset].to_i || 0
      rows = options[:rows].presence || job_batch_size
      from_date = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
      until_date = options[:until_date].presence || Time.now.to_date.iso8601

      updated = "updated:[#{from_date}T00:00:00Z TO #{until_date}T23:59:59Z]"
      fq = "#{updated} AND has_metadata:true AND is_active:true"

      params = { q: q,
                 start: offset,
                 rows: rows,
                 fl: "doi,creator,title,publisher,publicationYear,resourceTypeGeneral,datacentre_symbol,relatedIdentifier,nameIdentifier,xml,minted,updated",
                 fq: fq,
                 wt: "json" }
      url +  URI.encode_www_form(params)
    end

    def get_total(options={})
      query_url = get_query_url(options.merge(rows: 0))
      result = Maremma.get(query_url, options)
      result.body.fetch("data", {}).fetch("response", {}).fetch("numFound", 0)
    end

    def queue_jobs(options={})
      total = get_total(options)

      if total > 0
        # walk through paginated results
        total_pages = (total.to_f / job_batch_size).ceil

        (0...total_pages).each do |page|
          options[:offset] = page * job_batch_size
          process_data(options)
        end
      end

      # return number of works queued
      total
    end

    def process_data(options = {})
      data = get_data(options.merge(timeout: timeout, source_id: source_id))
      data = parse_data(data, options.merge(source_id: source_id))

      return [OpenStruct.new(body: { "data" => [] })] if data.empty?

      push_data(data, options)
    end

    def get_data(options={})
      query_url = get_query_url(options)
      Maremma.get(query_url, options)
    end

    def parse_data(result, options={})
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

      items = result.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
      get_relations_with_related_works(items)
    end

    # push to Lagotto deposit API if no error and we have collected works
    def push_data(items, options={})
      return [] if items.empty?

      Array(items).map do |item|
        relation = item.fetch(:relation, {})
        deposit = { "deposit" => { "subj_id" => relation.fetch("subj_id", nil),
                                   "obj_id" => relation.fetch("obj_id", nil),
                                   "relation_type_id" => relation.fetch("relation_type_id", nil),
                                   "source_id" => relation.fetch("source_id", nil),
                                   "publisher_id" => relation.fetch("publisher_id", nil),
                                   "subj" => item.fetch(:subj, {}),
                                   "obj" => item.fetch(:obj, {}),
                                   "message_type" => item.fetch(:message_type, "relation"),
                                   "prefix" => item.fetch(:prefix, nil),
                                   "source_token" => uuid } }

        Maremma.post push_url, data: deposit.to_json, content_type: 'json', token: access_token
      end
    end

    def get_relations_with_related_works(items)
      Array(items).reduce([]) do |sum, item|
        doi = item.fetch("doi", nil)
        prefix = doi[/^10\.\d{4,5}/]
        pid = doi_as_url(doi)
        type = item.fetch("resourceTypeGeneral", nil)
        publisher_id = item.fetch("datacentre_symbol", nil)

        xml = Base64.decode64(item.fetch('xml', "PGhzaD48L2hzaD4=\n"))
        xml = Hash.from_xml(xml).fetch("resource", {})
        authors = xml.fetch("creators", {}).fetch("creator", [])
        authors = [authors] if authors.is_a?(Hash)

        subj = { "pid" => pid,
                 "DOI" => doi,
                 "author" => get_hashed_authors(authors),
                 "title" => item.fetch("title", []).first,
                 "container-title" => item.fetch("publisher", nil),
                 "published" => item.fetch("publicationYear", nil),
                 "issued" => item.fetch("minted", nil),
                 "publisher_id" => publisher_id,
                 "registration_agency_id" => "datacite",
                 "tracked" => true,
                 "type" => type }

        related_doi_identifiers = item.fetch('relatedIdentifier', []).select { |id| id =~ /:DOI:.+/ }
        sum += get_doi_relations(subj, related_doi_identifiers)

        related_github_identifiers = item.fetch('relatedIdentifier', []).select { |id| id =~ /:URL:https:\/\/github.com.+/ }
        sum += get_github_relations(subj, related_github_identifiers)

        name_identifiers = item.fetch('nameIdentifier', []).select { |id| id =~ /^ORCID:.+/ }
        sum += get_contributions(subj, name_identifiers)

        if source_id == "datacite_import"
          sum += [{ prefix: prefix,
                    relation: { "subj_id" => subj["pid"],
                                "source_id" => source_id,
                                "publisher_id" => subj["publisher_id"],
                                "occurred_at" => subj["issued"] },
                    subj: subj }]
        end

        sum
      end
    end

    def get_github_relations(subj, items)
      prefix = subj["DOI"][/^10\.\d{4,5}/]

      Array(items).reduce([]) do |sum, item|
        raw_relation_type, _related_identifier_type, related_identifier = item.split(':', 3)

        # get parent repo
        # code from https://github.com/octokit/octokit.rb/blob/master/lib/octokit/repository.rb
        related_identifier = PostRank::URI.clean(related_identifier)
        github_hash = github_from_url(related_identifier)
        owner_url = github_as_owner_url(github_hash)
        repo_url = github_as_repo_url(github_hash)

        sum << { prefix: prefix,
                 relation: { "subj_id" => subj["pid"],
                             "obj_id" => related_identifier,
                             "relation_type_id" => raw_relation_type.underscore,
                             "source_id" => source_id,
                             "publisher_id" => subj["publisher_id"],
                             "registration_agency_id" => "github",
                             "occurred_at" => subj["issued"] },
                 subj: subj }

        # if relatedIdentifier is release URL rather than repo URL
        if related_identifier != repo_url
          sum << { relation: { "subj_id" => related_identifier,
                               "obj_id" => repo_url,
                               "relation_type_id" => "is_part_of",
                               "source_id" => source_id,
                               "publisher_id" => "github",
                               "registration_agency_id" => "github" } }
        end

        sum << {  message_type: "contribution",
                  relation: { "subj_id" => owner_url,
                              "obj_id" => repo_url,
                              "source_id" => "github_contributor",
                              "registration_agency_id" => "github" }}
      end
    end

    def get_doi_relations(subj, items)
      prefix = subj["DOI"][/^10\.\d{4,5}/]

      Array(items).reduce([]) do |sum, item|
        raw_relation_type, _related_identifier_type, related_identifier = item.split(':', 3)
        doi = related_identifier.strip.upcase
        registration_agency = get_doi_ra(doi)

        if source_id == "datacite_crossref" && registration_agency == "datacite"
          sum
        else
          _source_id = registration_agency == "crossref" ? "datacite_crossref" : "datacite_related"
          pid = doi_as_url(doi)

          sum << { prefix: prefix,
                   relation: { "subj_id" => subj["pid"],
                               "obj_id" => pid,
                               "relation_type_id" => raw_relation_type.underscore,
                               "source_id" => _source_id,
                               "publisher_id" => subj["publisher_id"],
                               "registration_agency_id" => registration_agency,
                               "occurred_at" => subj["issued"] },
                   subj: subj }
        end
      end
    end

    # we are flipping subj and obj for contributions
    def get_contributions(obj, items)
      prefix = obj["DOI"][/^10\.\d{4,5}/]

      Array(items).reduce([]) do |sum, item|
        orcid = item.split(':', 2).last
        orcid = validate_orcid(orcid)

        return sum if orcid.nil?

        sum << { prefix: prefix,
                 message_type: "contribution",
                 relation: { "subj_id" => orcid_as_url(orcid),
                             "obj_id" => obj["pid"],
                             "relation_type_id" => nil,
                             "source_id" => source_id,
                             "publisher_id" => obj["publisher_id"],
                             "registration_agency_id" => "datacite",
                             "occurred_at" => obj["issued"] },
                 obj: obj }
      end
    end

    def config_fields
      [:url, :push_url, :access_token]
    end

    def url
      "https://search.datacite.org/api?"
    end

    def timeout
      120
    end

    def job_batch_size
      1000
    end

    # remove non-printing whitespace
    def clean_doi(doi)
      doi.gsub(/\u200B/, '')
    end

    def doi_from_url(url)
      if /(http|https):\/\/(dx\.)?doi\.org\/(\w+)/.match(url)
        uri = Addressable::URI.parse(url)
        uri.path[1..-1].upcase
      elsif url.starts_with?("doi:")
        url[4..-1].upcase
      end
    end

    def doi_as_url(doi)
      Addressable::URI.encode("https://doi.org/#{clean_doi(doi)}") if doi.present?
    end

    def orcid_from_url(url)
      Array(/\Ahttp:\/\/orcid\.org\/(.+)/.match(url)).last
    end

    def orcid_as_url(orcid)
      "http://orcid.org/#{orcid}" if orcid.present?
    end

    def validate_orcid(orcid)
      Array(/\A(?:http:\/\/orcid\.org\/)?(\d{4}-\d{4}-\d{4}-\d{3}[0-9X]+)\z/.match(orcid)).last
    end

    # parse author string into CSL format
    # only assume personal name when using sort-order: "Turing, Alan"
    def get_one_author(author, options = {})
      return { "literal" => "" } if author.strip.blank?

      author = cleanup_author(author)
      names = Namae.parse(author)

      if names.blank? || is_personal_name?(author).blank?
        { "literal" => author }
      else
        name = names.first

        { "family" => name.family,
          "given" => name.given }.compact
      end
    end

    def cleanup_author(author)
      # detect pattern "Smith J.", but not "Smith, John K."
      author = author.gsub(/[[:space:]]([A-Z]\.)?(-?[A-Z]\.)$/, ', \1\2') unless author.include?(",")

      # titleize strings
      # remove non-standard space characters
      author.my_titleize
            .gsub(/[[:space:]]/, ' ')
    end

    def is_personal_name?(author)
      return true if author.include?(",")

      # lookup given name
      name_detector.name_exists?(author.split.first)
    end

    # parse array of author strings into CSL format
    def get_authors(authors, options={})
      Array(authors).map { |author| get_one_author(author, options) }
    end

    # parse array of author hashes into CSL format
    def get_hashed_authors(authors)
      Array(authors).map { |author| get_one_hashed_author(author) }
    end

    def get_one_hashed_author(author)
      raw_name = author.fetch("creatorName", nil)

      author_hsh = get_one_author(raw_name)
      author_hsh["ORCID"] = get_name_identifier(author)
      author_hsh.compact
    end

    def get_name_identifier(author)
      name_identifier = author.fetch("nameIdentifier", nil)
      name_identifier_scheme = author.fetch("nameIdentifierScheme", "orcid").downcase
      if name_identifier_scheme == "orcid" && name_identifier = validate_orcid(name_identifier)
        "http://orcid.org/#{name_identifier}"
      else
        nil
      end
    end

    def name_detector
      GenderDetector.new
    end
  end
end

class String
  def my_titleize
    self.gsub(/(\b|_)(.)/) { "#{$1}#{$2.upcase}" }
  end
end
