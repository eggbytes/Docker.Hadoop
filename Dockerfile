#   Leon Justice <leonljustice@gmail.com> from
#   Hadoop 2.7.1 sudo-distributed node
#
#
#   Ubuntu 14.04.2, Hadoop 2.7.1, SSHD, Supervisord
#
#########################################################
#
#
#
#
#
#

FROM ubuntu:14.04.2
MAINTAINER Tianon Gravi <admwiggin@gmail.com> (@tianon)


# WORKING DIRECTORY FOR APPLIANCE
WORKDIR /usr/local

USER root

# APT-GET INSTALL PACKAGES

RUN apt-get update && apt-get install -y \
  openssh-server \
  openssh-client \
  supervisor \
  passwd \
  ssh \
  rsync \
  git \
  mercurial \
  subversion \
  vim \
  tar \
  wget \
  && apt-get -y clean && apt-get -y check


# GLOBAL AND ROOT USER SSH KEY GENERATIONS

RUN rm -rf /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_rsa_key /root/.ssh/id_rsa
RUN ssh-keygen -t dsa -P '' -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -t rsa -P '' -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys


# CREATE DIRECTORIES

RUN mkdir -p /var/log/supervisor \
 /etc/supervisor/conf.d \
 /var/run/sshd \
 /usr/java \
 /usr/local/hadoop \
 /var/run/hadoop \
 /var/log/hadoop \
 /usr/local/hadoop/data_store


# WGET HADOOP 2.7.1 && JAVA JDK-7U79

RUN wget -O hadoop.tar.gz  http://mirror.reverse.net/pub/apache/hadoop/common/hadoop-2.7.1/hadoop-2.7.1.tar.gz
RUN wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" -O java.tar.gz  http://download.oracle.com/otn-pub/java/jdk/7u79-b15/jdk-7u79-linux-x64.tar.gz



# EXTRACT TAR FILES

RUN  tar -xzvf hadoop.tar.gz -C /usr/local/hadoop/ --strip-components=1 
RUN  tar -xzvf java.tar.gz -C /usr/java/ --strip-components=1


# REMOVE COMPRESSED FILES

RUN rm -rf hadoop.tar.gz
RUN rm -rf java.tar.gz
RUN rm -rf /usr/local/hadoop/etc/hadoop/*



# DEPLOY ENVIRONMENT SPECIFIC CONFIGURATION FILES

ADD /hadoop-config/ /usr/local/hadoop/etc/hadoop/
ADD sshd.ini /etc/supervisor/conf.d/sshd.ini
ADD hadoop.ini /etc/supervisor/conf.d/hadoop.ini
ADD supervisord.conf /etc/supervisord.conf
ADD ssh_config /etc/ssh/ssh_config
RUN chmod -R 600 /root/.ssh
RUN chown -R root:root /root/.ssh

# fix the 254 error code
#RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
#RUN echo "UsePAM no" >> /etc/ssh/sshd_config
#RUN echo "Port 2212" >> /etc/ssh/sshd_config

# CHANGE PERMISSIONS

RUN chmod -R 755 /usr/local/hadoop
RUN chmod -R 755 /usr/java
RUN chmod -R 777 /usr/local/hadoop/data_store

# GLOBAL ENVIRONMENT SETTINGS
RUN sed s/HOSTNAME/$HOSTNAME/
RUN sed s/HOSTNAME/localhost/  > /usr/local/hadoop/etc/hadoop/core-site.xml
ENV HOSTNAME localhost
ENV TERM xterm
ENV SHELL /bin/bash
ENV PATH /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/hadoop/bin:/usr/local/hadoop/sbin:/usr/local/hadoop:/usr/local/hadoop/libexec:/usr/java/bin
ENV JAVA_HOME /usr/java
ENV HADOOP_HOME /usr/local/hadoop
ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_HOME/etc/hadoop
ENV HADOOP_OPTS $HADOOP_OPTS -Djava.library.path=/usr/local/hadoop/lib
ENV HADOOP_COMMON_LIB_NATIVE_DIR -Djava.library.path=/usr/local/hadoop/lib/native


# workingaround docker.io build error
#RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
#RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
#RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# START HADOOP
RUN $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_HOME/input


# START SSHD
RUN /usr/sbin/sshd

# TEST SSH CONNECTION
RUN ssh localhost

# FORMAT HDFS
RUN $HADOOP_HOME/bin/hdfs namenode -format

# RUNNING HADOOP SPECIFIC COMMANDS TO CONFIGURE HDFS
RUN $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -mkdir /user && $HADOOP_PREFIX/bin/hdfs dfs -mkdir /user/root

RUN $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -put etc/hadoop input && $HADOOP_PREFIX/sbin/start-yarn.sh

# CLEANING MY ROOM
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


#### OPEN PORTS ####

# HADOOP SPECIFIC PORTS OPENED TO ACCEPT TRAFFICE 
EXPOSE 50010 50020 50070 50075 50090 8030 8031 8032 8033 8040 8042 8088 19888 49707 22 9000 9001


# START SUPERVISORD
CMD /usr/bin/supervisord -c /etc/supervisord.conf



# END
