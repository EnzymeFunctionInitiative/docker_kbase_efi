FROM kbase/sdkpython:3.8.0

ENV PIP_PROGRESS_BAR=off
RUN apt-get -y update
RUN apt-get -y install libpng-dev libargtable2-dev zlib1g-dev libgd-dev libfreetype-dev libmariadb-dev-compat
RUN apt-get -y install cpanminus unzip git r-base dos2unix

RUN pip install --upgrade pip
RUN pip install weblogo pytest-subtests parameterized


###################################################################################################
# Install Perl modules
RUN apt-get -y install libarray-utils-perl libcapture-tiny-perl libconfig-inifiles-perl libdata-uuid-perl
RUN apt-get -y install libdbi-perl libdbd-mysql-perl libdbd-mariadb-perl libdbd-sqlite3-perl
RUN apt-get -y install libfile-slurp-perl libgd-perl libimager-perl libjson-perl liblist-moreutils-perl
RUN apt-get -y install liblog-message-simple-perl libmoose-perl libstatistics-descriptive-perl libstatistics-r-perl
RUN apt-get -y install libtest-exception-perl libxml-libxml-perl libxml-parser-perl libxml-writer-perl
RUN mkdir /build
WORKDIR /build
COPY cpanfile /build/cpanfile
RUN cpanm -v --installdeps .

# Force install the Bio::HMM:Logo module (it uses Consensus::Colors which doesn't have a perl
# installer).
RUN mkdir /build/consensus-colors
RUN mkdir /usr/lib/x86_64-linux-gnu/perl-base/Consensus
RUN curl -sL https://github.com/Janelia-Farm-Xfam/Consensus-Colors/archive/refs/heads/master.zip > /build/consensus-colors.zip
RUN unzip /build/consensus-colors.zip
RUN cp /build/Consensus-Colors-master/lib/Consensus/Colors.pm /usr/lib/x86_64-linux-gnu/perl-base/Consensus/
RUN cpanm -v --force https://github.com/Janelia-Farm-Xfam/Bio-HMM-Logo.git


###################################################################################################
# INSTALL APPS
RUN mkdir -p /apps/bin
RUN echo 'export PATH=$PATH:/apps/bin' > /apps/env.sh

#############################
# Install BLAST
RUN curl -sL https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.13.0/ncbi-blast-2.13.0+-x64-linux.tar.gz > /build/ncbi-blast-2.13.0+-x64-linux.tar.gz
#COPY ncbi-blast-2.13.0+-x64-linux.tar.gz /build/ncbi-blast-2.13.0+-x64-linux.tar.gz
RUN tar zxvf /build/ncbi-blast-2.13.0+-x64-linux.tar.gz
RUN mv /build/ncbi-blast-2.13.0+/bin /apps/ncbi-blast-2.13.0+
RUN echo 'export PATH=$PATH:/apps/ncbi-blast-2.13.0+' > /apps/blast_modern.sh
RUN curl -sL https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/blast-2.2.26-x64-linux.tar.gz > /build/blast-2.2.26-x64-linux.tar.gz
#COPY blast-2.2.26-x64-linux.tar.gz /build/blast-2.2.26-x64-linux.tar.gz
RUN tar zxvf /build/blast-2.2.26-x64-linux.tar.gz
RUN mv /build/blast-2.2.26/bin /apps/blast-2.2.26
RUN echo 'export PATH=$PATH:/apps/blast-2.2.26' > /apps/blast_legacy.sh

RUN rm -rf /build/*

#############################
# Install CD-HIT
RUN curl -sL https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz > /build/cd-hit-v4.8.1-2019-0228.tar.gz
WORKDIR /build
RUN tar zxvf cd-hit-v4.8.1-2019-0228.tar.gz
WORKDIR /build/cd-hit-v4.8.1-2019-0228
RUN make
WORKDIR /build
RUN mv cd-hit-v4.8.1-2019-0228 /apps/
RUN echo 'export PATH=$PATH:/apps/cd-hit-v4.8.1-2019-0228' >> /apps/env.sh

#############################
# Install
RUN curl -sL https://github.com/rcedgar/muscle/releases/download/5.1.0/muscle5.1.linux_intel64 > /apps/bin/muscle
#TODO: this is not a properly-licensed copy. It is only here for testing/MVP, and will be corrected before app moves to production
RUN curl -sL http://www.drive5.com/downloads/usearch11.0.667_i86linux32.gz > /build/usearch.gz
RUN gunzip /build/usearch.gz
RUN mv /build/usearch /apps/bin/usearch

#
RUN curl -sL http://www.clustal.org/omega/clustalo-1.2.4-Ubuntu-x86_64 > /apps/bin/clustalo

#
RUN curl -sL https://github.com/bbuchfink/diamond/releases/download/v0.9.30/diamond-linux64.tar.gz > /build/diamond-linux64.tar.gz
WORKDIR /build
RUN tar zxvf /build/diamond-linux64.tar.gz
RUN mv /build/diamond /apps/bin/diamond

###################################################################################################
# Install EFI apps
WORKDIR /apps

RUN mkdir /apps/shortbred
WORKDIR /apps/shortbred
RUN mkdir /apps/shortbred/sb_data
RUN mkdir /apps/shortbred/sb_code
RUN git clone https://github.com/EnzymeFunctionInitiative/ShortBRED.git
#TODO: for now, we just include the necessary data files inside the git repo, but eventually we may
# want to provide this as a separate download.
WORKDIR /apps/shortbred/ShortBRED
RUN unzip sb_data.zip
RUN mv sb_data/* /apps/shortbred/sb_data/
RUN unzip sb_code.zip
RUN mv sb_code/* /apps/shortbred/sb_code/
RUN rm -rf sb_data sb_code

RUN mkdir -p /data/efi/0.1
RUN mkdir -p /data/job

ARG RESETCONFIG=false

RUN apt-get install -y wget
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN apt-get update
RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
#RUN apt-get update
RUN add-apt-repository -y ppa:c2d4u.team/c2d4u4.0+
RUN apt-get update
RUN apt-get install -y r-cran-hmisc

### This is for KBase integration.
WORKDIR /kb/module
COPY ./requirements.txt /kb/module/requirements.txt
ENV PIP_PROGRESS_BAR=off
#RUN pip install --upgrade pip
RUN pip install -r requirements.txt
#RUN pip install -e git+https://github.com/kbase-sfa-2021/sfa.git#egg=base
RUN pip install -e git+https://github.com/nilsoberg/sfa.git@clients-callable#egg=base
RUN mkdir -p /kb/module/work
RUN chmod -R a+rw /kb/module


ENTRYPOINT [ "/bin/bash" ]

CMD [ ]

