# EPR Common Data API

## Overview

Restful API providing EPR data for reporting purposes.

## How To Run

### Prerequisites

In order to run the service you will need the following dependencies

- .NET 6

### Run

 On EPR.CommonDataService.API directory, execute

```
dotnet run
```

### Docker


Then run in terminal at the CommonDataService solution root:

```
docker build -t commondataservice -f EPR.CommonDataService.API/Dockerfile .
```

Then after that command has completed run:

```
docker run -p 5291:3000 --name commondataservicecontainer commondataservice   
```

Do a GET Request to ```http://localhost:5001/admin/health``` to confirm that the service is running

***NB: The docker build command will not execute successfully on a machine that has Zscaler installed.***

## How To Test

### Unit tests

On root directory, execute

```
dotnet test
```

### Pact tests

N/A

### Integration tests

N/A

## How To Debug

N/A

## Environment Variables - deployed environments

The structure of the appsettings can be found in the repository. Example configurations for the different environments can be found in [epr-app-config-settings](https://dev.azure.com/defragovuk/RWD-CPR-EPR4P-ADO/_git/epr-app-config-settings).


## Additional Information

N/A

### Logging into Azure

N/A

### Usage

N/A

### Monitoring and Health Check

Health check - ```{environment}/admin/health```

## Directory Structure

### Source files

- `EPR.CommonDataService.Api` - API .NET source files
- `EPR.CommonDataService.Api.UnitTests` - API .NET unit test files
- `EPR.CommonDataService.Core` - CORE .NET source files
- `EPR.CommonDataService.Core.UnitTests` - CORE .NET unit test files
- `EPR.CommonDataService.Data` - DATA .NET source files
- `EPR.CommonDataService.Data.UnitTests` - DATA .NET unit test files

## Contributing to this project

Please read the [contribution guidelines](CONTRIBUTING.md) before submitting a pull request.

## Licence

[Licence information](LICENCE.md).



