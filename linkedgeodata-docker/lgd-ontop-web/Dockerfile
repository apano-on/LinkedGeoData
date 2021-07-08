FROM ontop/ontop-endpoint:latest
WORKDIR /opt/ontop

ADD https://repo1.maven.org/maven2/org/postgresql/postgresql/42.2.19/postgresql-42.2.19.jar jdbc/

ADD lgd.obda input/lgd.obda
ADD lgd.owl input/lgd.owl
ADD lgd.portal.toml input/lgd.portal.toml
ADD catalog-v001.xml input/catalog-v001.xml
ADD library input/library

ADD create-properties.sh .
RUN chmod +x create-properties.sh
RUN sleep 3
# Substitute ':' with '\:' - affects e.g. url schemas


RUN ./create-properties.sh | sed 's|:|\\:|g' > input/lgd.properties

RUN env
RUN cat input/lgd.properties

EXPOSE 8080
