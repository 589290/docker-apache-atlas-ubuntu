FROM scratch
FROM ubuntu:18.04
ARG VERSION=2.2.0

RUN apt-get update \
    && apt-get -y install apt-utils \
    && apt-get -y upgrade \
    && apt-get -y install default-jre \
        openjdk-8-jdk-headless \
        wget \
        python \
        patch \
	    unzip \
    && cd /usr/local \
    && wget https://www-eu.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz \
    && tar -xzvf apache-maven-3.6.3-bin.tar.gz \
    && ln -s apache-maven-3.6.3 apache-maven \
    && cd /tmp \
    && wget https://dlcdn.apache.org/atlas/${VERSION}/apache-atlas-${VERSION}-sources.tar.gz \
    && mkdir -p /tmp/atlas-src \
    && tar --strip 1 -xzvf apache-atlas-${VERSION}-sources.tar.gz -C /tmp/atlas-src \
    && rm apache-atlas-${VERSION}-sources.tar.gz

COPY buildtools.patch /tmp/atlas-src

RUN cd /tmp/atlas-src \
    && patch pom.xml buildtools.patch

RUN cd /tmp/atlas-src \
    && export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64" \
    && export M2_HOME="/usr/local/apache-maven" \
    && export MAVEN_HOME="/usr/local/apache-maven" \
    && export PATH=${M2_HOME}/bin:${PATH} \
    && export MAVEN_OPTS="-Xms2g -Xmx2g" \
    && mvn clean -Dmaven.repo.local=/tmp/.mvn-repo -Dhttps.protocols=TLSv1.2 -DskipTests package -Pdist,embedded-hbase-solr \
    && tar -xzvf /tmp/atlas-src/distro/target/apache-atlas-${VERSION}-server.tar.gz -C /opt \
    && rm -Rf /tmp/atlas-src \
    && rm -Rf /tmp/.mvn-repo \
    && apt-get -y remove openjdk-11-jre-headless \
    && apt-get -y autoremove \
    && apt-get -y clean

VOLUME ["/opt/apache-atlas-${VERSION}/conf", "/opt/apache-atlas-${VERSION}/logs", "/opt"]

COPY atlas_start.py.patch atlas_config.py.patch /opt/apache-atlas-${VERSION}/bin/

RUN cd /opt/apache-atlas-${VERSION}/bin \
    && patch -b -f < atlas_start.py.patch \
    && patch -b -f < atlas_config.py.patch

COPY atlas-env.sh /opt/apache-atlas-${VERSION}/conf/atlas-env.sh

#RUN cd /opt/apache-atlas-${VERSION} \
#    && ./bin/atlas_start.py -setup || true

#RUN cd /opt/apache-atlas-${VERSION} \
#    && ./bin/atlas_start.py & \
#    touch /opt/apache-atlas-${VERSION}/logs/application.log \
#    && tail -f /opt/apache-atlas-${VERSION}/logs/application.log | sed '/AtlasAuthenticationFilter.init(filterConfig=null)/ q' \
#    && sleep 10 \
#    && /opt/apache-atlas-${VERSION}/bin/atlas_stop.py

RUN apt-get -y install tmux
COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]