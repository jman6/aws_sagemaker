FROM public.ecr.aws/lambda/provided

ENV R_VERSION=4.1.2
ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

# install dependencies for libgit2-devel
RUN yum -y install cmake \
    pkg-config \
    git

# install libgit2-devel
RUN git clone --depth=1 -b v1.0.0 https://github.com/libgit2/libgit2.git ~/libgit2_src \
    && cd ~/libgit2_src \
    && cmake . -DBUILD_CLAR=OFF -DCMAKE_BUILD_TYPE=Release -DEMBED_SSH_PATH=~/libssh2_src -DCMAKE_INSTALL_PREFIX=~/libgit2 \
    && cmake --build . --target install \
    && cp -r ~/libgit2/* /usr/bin \
    && cp -r ~/libgit2/* /usr/local

# install R
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && yum -y install https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
    openssl-devel \
    libxml2-devel \
    unzip \
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
