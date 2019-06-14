FROM metalnx/metalnx-web:1.1.0-latest

RUN yum makecache fast
RUN yum -y update

RUN yum install -y vim git maven

RUN git clone https://github.com/irods-contrib/metalnx-irods-test-connection.git
RUN cd metalnx-irods-test-connection && mvn package

ADD start_metalnx.sh /
