FROM defradigital/dotnetcore-development:dotnet10.0 AS build
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
FROM build AS publish
RUN dotnet publish "EPR.CommonDataService.Api.csproj" -c Release /p:AzureBuild=true --no-restore -o /app/publish

FROM defradigital/dotnetcore:dotnet10.0 AS final

USER root
ENV ASPNETCORE_URLS=http://*:8080
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0
EXPOSE 8080

RUN apk add --no-cache icu-libs

# Switch to the non-root user
USER dotnet

WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "EPR.CommonDataService.Api.dll"]
