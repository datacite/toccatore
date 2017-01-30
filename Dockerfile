FROM phusion/passenger-full:0.9.19
MAINTAINER Martin Fenner "mfenner@datacite.org"

ENV ACCESS_TOKEN=1
ENV PATH="/usr/local/rvm/gems/ruby-2.3.1/bin:${PATH}"

# Update installed APT packages, clean up APT when done.
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install toccatore gem
RUN /sbin/setuser app gem install toccatore

#CMD ["/usr/local/rvm/gems/ruby-2.3.1/bin/toccatore", "--access_token", ${access_token}]
# CMD ["/sbin/my_init"]
CMD ["toccatore", "orcid_update"]
