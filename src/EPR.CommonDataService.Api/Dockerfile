FROM defradigital/dotnetcore:dotnet6.0 AS base
USER root
ENV ASPNETCORE_URLS=http://*:8080
EXPOSE 8080

RUN apk update && apk --no-cache add icu-libs
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0

FROM defradigital/dotnetcore-development:dotnet6.0 AS build
USER root
WORKDIR /src
COPY ["EPR.CommonDataService.Api/EPR.CommonDataService.Api.csproj", "EPR.CommonDataService.Api/"]
COPY ["EPR.CommonDataService.Core/EPR.CommonDataService.Core.csproj", "EPR.CommonDataService.Core/"]
COPY ["EPR.CommonDataService.Data/EPR.CommonDataService.Data.csproj", "EPR.CommonDataService.Data/"]
RUN dotnet restore "EPR.CommonDataService.Api/EPR.CommonDataService.Api.csproj"

COPY EPR.CommonDataService.Api/. ./EPR.CommonDataService.Api/.
COPY EPR.CommonDataService.Core/. ./EPR.CommonDataService.Core/.
COPY EPR.CommonDataService.Data/. ./EPR.CommonDataService.Data/.

WORKDIR "/src/EPR.CommonDataService.Api"
RUN dotnet build "EPR.CommonDataService.Api.csproj" -c Release /p:AzureBuild=true -o /app/build

FROM build AS publish
RUN dotnet publish "EPR.CommonDataService.Api.csproj" -c Release /p:AzureBuild=true -o /app/publish

FROM base AS final

# Switch to the non-root user
USER dotnet

WORKDIR /app
COPY --from=publish /app/publish .
USER dotnet
ENTRYPOINT ["dotnet", "EPR.CommonDataService.Api.dll"]
