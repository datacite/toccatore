# Toccatore

[![Build Status](https://travis-ci.org/datacite/toccatore.svg?branch=master)](https://travis-ci.org/datacite/toccatore)
[![Code Climate](https://codeclimate.com/github/datacite/toccatore/badges/gpa.svg)](https://codeclimate.com/github/datacite/toccatore)
[![Test Coverage](https://codeclimate.com/github/datacite/toccatore/badges/coverage.svg)](https://codeclimate.com/github/datacite/toccatore/coverage)

Agent for Event Data service. Extracts links to ORCID IDs and DOIs not from DataCite from DataCite metadata, and pushes them to the other services.

## Installation and use

```
gem install toccatore
toccatore datacite_related --push_url https://example.org --access_token abc
```

Or run as Docker container

```
docker run datacite/toccatore toccatore datacite_related --push_url https://example.org --access_token abc
```

## Development

We use rspec for unit testing:

```
bundle exec rspec
```

Follow along via [Github Issues](https://github.com/datacite/toccatore/issues).

### Note on Patches/Pull Requests

* Fork the project
* Write tests for your new feature or a test that reproduces a bug
* Implement your feature or make a bug fix
* Do not mess with Rakefile, version or history
* Commit, push and make a pull request. Bonus points for topical branches.

## License
**toccatore** is released under the [MIT License](https://github.com/datacite/toccatore/blob/master/LICENSE.md).
