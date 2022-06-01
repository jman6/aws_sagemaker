# use public aws linux distribution
FROM public.ecr.aws/lambda/provided

ARG TOKEN=${TOKEN}
ENV TOKEN=${TOKEN}

# set up R version and path
ENV R_VERSION=4.1.2
ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

# install R
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && yum -y install https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
    openssl-devel \
    libxml2-devel \
    unzip \
    git \
    && yum clean all \
    && rm -rf /var/cache/yum/*
    
# install sudo, wget and openssl which are required for building CMake
RUN yum install sudo wget openssl-devel -y

# dnstall development tools
RUN sudo yum groupinstall "Development Tools" -y

# download, build and install cmake
RUN wget https://cmake.org/files/v3.18/cmake-3.18.0.tar.gz \
    && tar -xvzf cmake-3.18.0.tar.gz \
    && cd cmake-3.18.0 \
    && ./bootstrap \
    && make \
    && sudo make install
    
# install git and pkg-config which are required for building libgit2
RUN yum -y install git \
    pkg-config
    
# clone libgit2 from source as it is a dependency for R package 'devtools' and is not yet available in Amazon Linux
RUN git clone "https://github.com/libgit2/libgit2" \
    && cd libgit2 \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build . --target install \
    && cd .. \
    && rm -rf libgit2

# install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -f awscliv2.zip

# install R packages
RUN Rscript -e "install.packages(c('httr', 'logger', 'glue', 'jsonlite', 'Rcpp', 'ranger', 'devtools'), repos = 'https://cloud.r-project.org/')"
RUN git clone https://${TOKEN}@github.com/EliLillyCo/dhai.ca.model.git \
    && cd dhai.ca.model
RUN Rscript -e "devtools::install('dhai.ca.model')"

# Copy R runtime and inference code
COPY runtime.R predict.R ${LAMBDA_TASK_ROOT}/
RUN chmod 755 -R ${LAMBDA_TASK_ROOT}/

COPY bootstrap ${LAMBDA_RUNTIME_DIR}/
RUN chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap
RUN rm -rf /tmp/*

CMD [ "predict.handler" ]
