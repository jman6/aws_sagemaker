FROM public.ecr.aws/lambda/provided:al2.2022.05.31.10

ENV R_VERSION=4.1.2
ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

RUN yum -y install git \
    cmake \
    pkg-config
    
RUN git clone "https://github.com/libgit2/libgit2" \
    && cd libgit2 \
    && mkdir build && cd build \
    && sudo su \
    && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build . --target install \
    && cd .. \
    && rm -rf libgit2

# install R
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && yum -y install https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
    openssl-devel \
    libxml2-devel \
    unzip \
    git \
    && yum clean all \
    && rm -rf /var/cache/yum/*

# install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -f awscliv2.zip

# install R packages
RUN Rscript -e "install.packages(c('httr', 'logger', 'glue', 'jsonlite', 'Rcpp', 'ranger', 'devtools'), repos = 'https://cloud.r-project.org/')"
RUN git clone https://github.com/jman6/aws_sagemaker.git
RUN Rscript -e "devtools::install('aws_sagemaker')"

# Copy R runtime and inference code
COPY runtime.R predict.R ${LAMBDA_TASK_ROOT}/
RUN chmod 755 -R ${LAMBDA_TASK_ROOT}/

COPY bootstrap ${LAMBDA_RUNTIME_DIR}/
RUN chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap
RUN rm -rf /tmp/*

CMD [ "predict.handler" ]
