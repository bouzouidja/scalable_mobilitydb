# This file is auto generated from it's template,
# see citusdata/tools/packaging_automation/templates/docker/latest/latest.tmpl.dockerfile.
FROM postgres:13.3
ARG VERSION=10.1.0
LABEL maintainer="Citus Data https://citusdata.com" \
      org.label-schema.name="Citus" \
      org.label-schema.description="Scalable MobilityDB" \
      org.label-schema.url="https://www.citusdata.com" \
      org.label-schema.vcs-url="https://github.com/bouzouidja/scalable_mobilitydb" \
      org.label-schema.vendor="Citus Data, Inc." \
      org.label-schema.version=${VERSION} \
      org.label-schema.schema-version="1.0"

ENV CITUS_VERSION ${VERSION}.citus-1
ENV POSTGIS_VERSION 2.5

# Fix the Release file expired problem
RUN echo "Acquire::Check-Valid-Until \"false\";\nAcquire::Check-Date \"false\";" | cat > /etc/apt/apt.conf.d/10no--check-valid-until

# install Citus
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       build-essential \
       cmake \
       git \
       libproj-dev \    
       g++ \
       wget \
       autoconf \
       autotools-dev \
       libgeos-dev \
       libpq-dev \
       liblwgeom-dev \
       libproj-dev \
       libjson-c-dev \
       protobuf-c-compiler \
       xsltproc \
       libgsl-dev \
       libgslcblas0 \
       postgresql-server-dev-13 \
    && apt-cache showpkg postgresql-13-postgis-$POSTGIS_VERSION \
    && apt-get install -y \
       postgresql-13-postgis-$POSTGIS_VERSION \
       postgresql-13-postgis-$POSTGIS_VERSION-scripts \
    && rm -rf /var/lib/apt/lists/*
RUN curl -s https://install.citusdata.com/community/deb.sh | bash \
    && apt-get install -y postgresql-$PG_MAJOR-citus-10.1.=$CITUS_VERSION \
                          postgresql-$PG_MAJOR-hll=2.15.citus-1 \
                          postgresql-$PG_MAJOR-topn=2.3.1 \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*




# Install MobilityDB 
RUN cd /usr/local/src/ \
  && git clone https://github.com/MobilityDB/MobilityDB.git \
  && cd MobilityDB \
  && git checkout ${MOBILITYDB_GIT_HASH} \
  && mkdir build \
  && cd build && \
	cmake .. && \
	make -j$(nproc) && \
	make install


RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-mobilitydb.sh /docker-entrypoint-initdb.d/mobilitydb.sh
RUN chmod +x /docker-entrypoint-initdb.d/mobilitydb.sh


# add citus to default PostgreSQL config
RUN echo "shared_preload_libraries='citus'" >> /usr/share/postgresql/postgresql.conf.sample

# add scripts to run after initdb
COPY 001-create-citus-extension.sql /docker-entrypoint-initdb.d/

# add health check script
COPY pg_healthcheck wait-for-manager.sh /
RUN chmod +x /wait-for-manager.sh

# entry point unsets PGPASSWORD, but we need it to connect to workers
# https://github.com/docker-library/postgres/blob/33bccfcaddd0679f55ee1028c012d26cd196537d/12/docker-entrypoint.sh#L303
RUN sed "/unset PGPASSWORD/d" -i /usr/local/bin/docker-entrypoint.sh

HEALTHCHECK --interval=4s --start-period=6s CMD ./pg_healthcheck
