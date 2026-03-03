using EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Organisations.StreamOut;

[ExcludeFromCodeCoverage]
[TestClass]
public class StreamOrganisationsRequestHandlerTests
{
    private SynapseContext _dbContext = null!;
    private StreamOrganisationsRequestHandler _handler = null!;

    [TestInitialize]
    public void Setup()
    {
        var options = new DbContextOptionsBuilder<SynapseContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _dbContext = new SynapseContext(options);
        _handler = new StreamOrganisationsRequestHandler(_dbContext);
    }

    [TestCleanup]
    public void Cleanup()
    {
        _dbContext.Dispose();
    }

    [TestMethod]
    public async Task Handle_WhenNoOrganisationsExist_ShouldReturnEmptyEnumerable()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<OrganisationResponse>();
        await foreach (var org in _handler.Handle(request))
        {
            results.Add(org);
        }

        // Assert
        results.Should().BeEmpty();
    }

    [TestMethod]
    public async Task Handle_WhenOrganisationsExistForYear_ShouldReturnMatchingOrganisations()
    {
        // Arrange
        var orgData = new PayCalOrganisation
        {
            OrganisationId = 123,
            SubsidiaryId = "SUB001",
            SubmitterId = "b2c3d4e5-f6a7-8901-bcde-f12345678901",
            OrganisationName = "Test Organisation",
            TradingName = "Test Trading",
            StatusCode = "Active",
            ErrorCode = null,
            JoinerDate = "2025-01-01",
            LeaverDate = null,
            ObligationStatus = "Obligated",
            NumDaysObligated = 365,
            SubmissionPeriodYear = 2025
        };

        _dbContext.PayCalOrganisations.Add(orgData);
        await _dbContext.SaveChangesAsync();

        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<OrganisationResponse>();
        await foreach (var org in _handler.Handle(request))
        {
            results.Add(org);
        }

        // Assert
        results.Should().HaveCount(1);
        var result = results[0];
        result.OrganisationId.Should().Be(123);
        result.SubsidiaryId.Should().Be("SUB001");
        result.SubmitterId.Should().Be("b2c3d4e5-f6a7-8901-bcde-f12345678901");
        result.OrganisationName.Should().Be("Test Organisation");
        result.TradingName.Should().Be("Test Trading");
        result.StatusCode.Should().Be("Active");
        result.ErrorCode.Should().BeNull();
        result.JoinerDate.Should().Be("2025-01-01");
        result.LeaverDate.Should().BeNull();
        result.ObligationStatus.Should().Be("Obligated");
        result.NumDaysObligated.Should().Be(365);
    }

    [TestMethod]
    public async Task Handle_WhenOrganisationsExistForDifferentYear_ShouldReturnOnlyMatchingYear()
    {
        // Arrange
        var org2025 = new PayCalOrganisation
        {
            OrganisationId = 1,
            OrganisationName = "Org 2025",
            SubmissionPeriodYear = 2025
        };

        var org2026 = new PayCalOrganisation
        {
            OrganisationId = 2,
            OrganisationName = "Org 2026",
            SubmissionPeriodYear = 2026
        };

        _dbContext.PayCalOrganisations.AddRange(org2025, org2026);
        await _dbContext.SaveChangesAsync();

        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<OrganisationResponse>();
        await foreach (var org in _handler.Handle(request))
        {
            results.Add(org);
        }

        // Assert
        results.Should().HaveCount(1);
        var result = results[0];
        result.OrganisationId.Should().Be(1);
    }

    [TestMethod]
    public async Task Handle_WhenMultipleOrganisationsExistForYear_ShouldReturnAllMatchingOrganisations()
    {
        // Arrange
        var orgs = Enumerable.Range(1, 5).Select(i => new PayCalOrganisation
        {
            OrganisationId = i,
            OrganisationName = $"Organisation {i}",
            SubmissionPeriodYear = 2025
        }).ToList();

        _dbContext.PayCalOrganisations.AddRange(orgs);
        await _dbContext.SaveChangesAsync();

        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };

        // Act
        var results = new List<OrganisationResponse>();
        await foreach (var org in _handler.Handle(request))
        {
            results.Add(org);
        }

        // Assert
        results.Should().HaveCount(5);
    }

    [TestMethod]
    public async Task Handle_WhenCancellationRequested_ShouldStopEnumeration()
    {
        // Arrange
        var orgs = Enumerable.Range(1, 10).Select(i => new PayCalOrganisation
        {
            OrganisationId = i,
            OrganisationName = $"Organisation {i}",
            SubmissionPeriodYear = 2025
        }).ToList();

        _dbContext.PayCalOrganisations.AddRange(orgs);
        await _dbContext.SaveChangesAsync();

        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };
        using var cts = new CancellationTokenSource();

        // Act
        var results = new List<OrganisationResponse>();
        var count = 0;
        await foreach (var org in _handler.Handle(request).WithCancellation(cts.Token))
        {
            results.Add(org);
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