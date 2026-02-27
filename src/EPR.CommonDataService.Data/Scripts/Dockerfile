FROM mcr.microsoft.com/mssql-tools

# Create a non-root user and define a directory it can use
RUN useradd -m -d /home/nonroot -s /bin/bash nonroot

# Change to the non-root user
USER nonroot

# Create the directory fornon-root user and set it as the working directory
RUN mkdir /home/nonroot/sql
WORKDIR /home/nonroot/sql

# Copy the migration files and scripts
COPY ["Create Tables/.", "./scripts/tables/"]
COPY Functions/. ./scripts/functions/
COPY ["Stored Procedures/.", "./scripts/procedures/"]
COPY Views/. ./scripts/views/
COPY --chown=nonroot run-migrations.sh .

RUN chmod +x run-migrations.sh
CMD ["/bin/bash", "/home/nonroot/sql/run-migrations.sh"]
