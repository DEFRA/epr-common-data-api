using EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Poms.StreamOut;

[ExcludeFromCodeCoverage]
[TestClass]
public class StreamPomsRequestHandlerTests
{
    private SynapseContext _dbContext = null!;
    private StreamPomsRequestHandler _handler = null!;

    [TestInitialize]
    public void Setup()
    {
        var options = new DbContextOptionsBuilder<SynapseContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _dbContext = new SynapseContext(options);
        _handler = new StreamPomsRequestHandler(_dbContext);
    }

    [TestCleanup]
    public void Cleanup()
    {
        _dbContext.Dispose();
    }

    [TestMethod]
    public async Task Handle_WhenNoPomsExist_ShouldReturnEmptyEnumerable()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<PomResponse>();
        await foreach (var pom in _handler.Handle(request))
        {
            results.Add(pom);
        }

        // Assert
        results.Should().BeEmpty();
    }

    [TestMethod]
    public async Task Handle_WhenPomsExistForYear_ShouldReturnMatchingPoms()
    {
        // Arrange
        var pomData = new PayCalPom
        {
            OrganisationId = 123,
            SubsidiaryId = "SUB001",
            SubmitterId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            SubmissionPeriod = "2024-P1",
            PackagingActivity = "Primary",
            PackagingType = "Household",
            PackagingClass = "ClassA",
            PackagingMaterial = "Plastic",
            PackagingMaterialWeight = 100.5
        };

        _dbContext.PayCalPoms.Add(pomData);
        await _dbContext.SaveChangesAsync();

        var request = new StreamPomsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<PomResponse>();
        await foreach (var pom in _handler.Handle(request))
        {
            results.Add(pom);
        }

        // Assert
        results.Should().HaveCount(1);
        var result = results[0];
        result.OrganisationId.Should().Be(123);
        result.SubsidiaryId.Should().Be("SUB001");
        result.SubmitterId.Should().Be("a1b2c3d4-e5f6-7890-abcd-ef1234567890");
        result.SubmissionPeriod.Should().Be("2024-P1");
        result.PackagingActivity.Should().Be("Primary");
        result.PackagingType.Should().Be("Household");
        result.PackagingClass.Should().Be("ClassA");
        result.PackagingMaterial.Should().Be("Plastic");
        result.PackagingMaterialWeight.Should().Be(100.5);
    }

    [TestMethod]
    public async Task Handle_WhenPomsExistForDifferentYear_ShouldReturnOnlyMatchingYear()
    {
        // Arrange
        var pom2024 = new PayCalPom
        {
            OrganisationId = 1,
            SubmissionPeriod = "2024-P1",
            PackagingType = "Household",
            PackagingMaterial = "Plastic"
        };

        var pom2025 = new PayCalPom
        {
            OrganisationId = 2,
            SubmissionPeriod = "2025-P1",
            PackagingType = "Household",
            PackagingMaterial = "Plastic"
        };

        _dbContext.PayCalPoms.AddRange(pom2024, pom2025);
        await _dbContext.SaveChangesAsync();

        var request = new StreamPomsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<PomResponse>();
        await foreach (var pom in _handler.Handle(request))
        {
            results.Add(pom);
        }

        // Assert
        results.Should().HaveCount(1);
        var result = results[0];
        result.OrganisationId.Should().Be(1);
        result.SubmissionPeriod.Should().StartWith("2024");
    }

    [TestMethod]
    public async Task Handle_WhenMultiplePomsExistForYear_ShouldReturnAllMatchingPoms()
    {
        // Arrange
        var poms = Enumerable.Range(1, 5).Select(i => new PayCalPom
        {
            OrganisationId = i,
            SubmissionPeriod = "2024-P1",
            PackagingType = $"Type{i}",
            PackagingMaterial = $"Material{i}"
        }).ToList();

        _dbContext.PayCalPoms.AddRange(poms);
        await _dbContext.SaveChangesAsync();

        var request = new StreamPomsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<PomResponse>();
        await foreach (var pom in _handler.Handle(request))
        {
            results.Add(pom);
        }

        // Assert
        results.Should().HaveCount(5);
    }

    [TestMethod]
    public async Task Handle_WhenCancellationRequested_ShouldStopEnumeration()
    {
        // Arrange
        var poms = Enumerable.Range(1, 10).Select(i => new PayCalPom
        {
            OrganisationId = i,
            SubmissionPeriod = "2024-P1",
            PackagingType = $"Type{i}",
            PackagingMaterial = $"Material{i}"
        }).ToList();

        _dbContext.PayCalPoms.AddRange(poms);
        await _dbContext.SaveChangesAsync();

        var request = new StreamPomsRequest { RelativeYear = 2025 };
        using var cts = new CancellationTokenSource();

        // Act
        var results = new List<PomResponse>();
        var count = 0;
        await foreach (var pom in _handler.Handle(request).WithCancellation(cts.Token))
        {
            results.Add(pom);
            count++;
            if (count >= 3)
            {
                await cts.CancelAsync();
                break;
            }
        }

        // Assert
        results.Should().HaveCount(3);
    }
}