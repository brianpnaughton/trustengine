FROM postgres:16

# Install necessary dependencies and extensions
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    libreadline-dev \
    zlib1g-dev \
    bison \
    flex \
    git \
    curl \
    postgresql-server-dev-16 

# Clone Apache AGE
RUN git clone https://github.com/apache/age.git /age

# Build and install Apache AGE
RUN cd /age && \
    make && \
    make install

# Clone pgvector extension
RUN git clone https://github.com/pgvector/pgvector.git /pgvector

# Build and install pgvector
RUN cd /pgvector && \
    make && \
    make install

# Add Apache AGE and pgvector to the shared_preload_libraries
RUN echo "shared_preload_libraries = 'age,vector'" >> /usr/share/postgresql/postgresql.conf.sample

# Expose PostgreSQL port
EXPOSE 5432

# Start PostgreSQL
CMD ["postgres"]