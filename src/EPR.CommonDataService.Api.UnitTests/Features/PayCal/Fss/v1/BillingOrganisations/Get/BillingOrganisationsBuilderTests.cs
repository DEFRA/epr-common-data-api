using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;
using EPR.CommonDataService.Data.Entities;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Fss.v1.BillingOrganisations.Get;

[ExcludeFromCodeCoverage]
[TestClass]
public class BillingOrganisationsBuilderTests
{
    private Mock<ILogger> _mockLogger = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockLogger = new Mock<ILogger>();
    }

    [TestMethod]
    public void Build_WhenNoRows_ShouldReturnEmpty()
    {
        // Act
        var result = BillingOrganisationsBuilder.Build([], _mockLogger.Object);

        // Assert
        result.Should().BeEmpty();
    }

    [TestMethod]
    public void Build_WhenParentRow_ShouldMapAllFields()
    {
        // Arrange
        var row = CreateRow(12345) with
        {
            OrganisationName = "Example Organisation Ltd",
            TradingName = "Example Trading Name",
            CompaniesHouseNumber = "12345678",
            HomeNationCode = "ENG",
            ServiceOfNoticeAddrLine1 = "123 Example Street",
            ServiceOfNoticeAddrLine2 = "Suite 456",
            ServiceOfNoticeAddrCity = "London",
            ServiceOfNoticeAddrCounty = "Greater London",
            ServiceOfNoticeAddrCountry = "United Kingdom",
            ServiceOfNoticeAddrPostcode = "E1 6AN",
            ServiceOfNoticeAddrPhoneNumber = "+44 20 7946 0123",
            SoleTraderFirstName = "John",
            SoleTraderLastName = "Doe",
            SoleTraderPhoneNumber = "+44 7911 123456",
            SoleTraderEmail = "john.doe@example.com",
            PrimaryContactPersonFirstName = "Jane",
            PrimaryContactPersonLastName = "Smith",
            PrimaryContactPersonPhoneNumber = "+44 7911 654321",
            PrimaryContactPersonEmail = "jane.smith@example.com",
            DecisionDate = "2025-06-01T10:30:00.0000000Z"
        };

        // Act
        var result = BillingOrganisationsBuilder.Build([row], _mockLogger.Object);

        // Assert
        result.Should().ContainSingle().Which.Should().BeEquivalentTo(new BillingOrganisationResponse
        {
            OrganisationId = "12345",
            FinancialYear = "2025-26",
            ApprovedDate = new DateTime(2025, 6, 1, 10, 30, 0, DateTimeKind.Utc),
            OrganisationName = "Example Organisation Ltd",
            OrganisationTradingName = "Example Trading Name",
            CompaniesHouseNumber = "12345678",
            HomeNationCode = "ENG",
            ServiceOfNoticeAddrLine1 = "123 Example Street",
            ServiceOfNoticeAddrLine2 = "Suite 456",
            ServiceOfNoticeAddrCity = "London",
            ServiceOfNoticeAddrCounty = "Greater London",
            ServiceOfNoticeAddrCountry = "United Kingdom",
            ServiceOfNoticeAddrPostcode = "E1 6AN",
            ServiceOfNoticeAddrPhoneNumber = "+44 20 7946 0123",
            SoleTraderFirstName = "John",
            SoleTraderLastName = "Doe",
            SoleTraderPhoneNumber = "+44 7911 123456",
            SoleTraderEmail = "john.doe@example.com",
            PrimaryContactPersonFirstName = "Jane",
            PrimaryContactPersonLastName = "Smith",
            PrimaryContactPersonPhoneNumber = "+44 7911 654321",
            PrimaryContactPersonEmail = "jane.smith@example.com",
            SubsidiaryDetails = []
        });
    }

    [TestMethod]
    public void Build_WhenMultipleOrganisations_ShouldOrderByOrganisationId()
    {
        // Arrange
        var rows = new[] { CreateRow(67890), CreateRow(9), CreateRow(12345) };

        // Act
        var result = BillingOrganisationsBuilder.Build(rows, _mockLogger.Object);

        // Assert
        result.Select(x => x.OrganisationId).Should().Equal("9", "12345", "67890");
    }

    [TestMethod]
    public void Build_WhenSubsidiaryRow_ShouldNestUnderParent()
    {
        // Arrange
        var rows = new[]
        {
            CreateRow(12345),
            CreateRow(12345) with
            {
                SubsidiaryId = "900001",
                OrganisationName = "Happy Shopper",
                TradingName = "Subsidiary Trading Name",
                DecisionDate = "2025-06-02T00:00:00.0000000Z"
            }
        };

        // Act
        var result = BillingOrganisationsBuilder.Build(rows, _mockLogger.Object);

        // Assert
        result.Should().ContainSingle().Which.SubsidiaryDetails.Should().ContainSingle()
            .Which.Should().BeEquivalentTo(new BillingSubsidiaryResponse
            {
                SubsidiaryId = "900001",
                SubsidiaryName = "Happy Shopper",
                SubsidiaryTradingName = "Subsidiary Trading Name",
                FinancialYear = "2025-26",
                ApprovedDate = new DateTime(2025, 6, 2, 0, 0, 0, DateTimeKind.Utc)
            });
    }

    [TestMethod]
    [DataRow("")]
    [DataRow(" ")]
    public void Build_WhenSubsidiaryIdIsBlank_ShouldTreatRowAsParent(string subsidiaryId)
    {
        // Arrange
        var row = CreateRow(12345) with { SubsidiaryId = subsidiaryId };

        // Act
        var result = BillingOrganisationsBuilder.Build([row], _mockLogger.Object);

        // Assert
        result.Should().ContainSingle().Which.SubsidiaryDetails.Should().BeEmpty();
    }

    [TestMethod]
    public void Build_WhenNoParentRow_ShouldSkipOrganisationAndLogWarning()
    {
        // Arrange
        var rows = new[]
        {
            CreateRow(12345) with { SubsidiaryId = "000111" },
            CreateRow(67890),
            CreateRow(67890) with { SubsidiaryId = "900001" }
        };

        // Act
        var result = BillingOrganisationsBuilder.Build(rows, _mockLogger.Object);

        // Assert
        result.Should().ContainSingle().Which.OrganisationId.Should().Be("67890");

        _mockLogger.Verify(
            logger => logger.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((state, _) => state.ToString()!.Contains("OrganisationId=12345")),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public void Build_WhenOrganisationIdIsNull_ShouldIgnoreRow()
    {
        // Arrange
        var rows = new[] { CreateRow(12345), CreateRow(0) with { OrganisationId = null } };

        // Act
        var result = BillingOrganisationsBuilder.Build(rows, _mockLogger.Object);

        // Assert
        result.Should().ContainSingle().Which.OrganisationId.Should().Be("12345");
    }

    [TestMethod]
    public void Build_WhenMultipleParentRows_ShouldUseLatestDecisionDate()
    {
        // Arrange
        var rows = new[]
        {
            CreateRow(12345) with
            {
                OrganisationName = "Example Organisation Ltd",
                RelativeYear = 2025,
                DecisionDate = "2025-06-01T00:00:00.0000000Z"
            },
            CreateRow(12345) with
            {
                OrganisationName = "Example Organisation Ltd - UPDATED",
                RelativeYear = 2026,
                DecisionDate = "2025-06-02T00:00:00.0000000Z"
            }
        };

        // Act
        var result = BillingOrganisationsBuilder.Build(rows, _mockLogger.Object);

        // Assert
        var organisation = result.Should().ContainSingle().Subject;
        organisation.OrganisationName.Should().Be("Example Organisation Ltd - UPDATED");
        organisation.FinancialYear.Should().Be("2026-27");
    }

    [TestMethod]
    public void Build_WhenSubsidiaryRelativeYearDiffersFromParent_ShouldExcludeSubsidiary()
    {
        // Arrange
        var rows = new[]
        {
            CreateRow(12345) with { RelativeYear = 2026 },
            CreateRow(12345) with { SubsidiaryId = "900001", RelativeYear = 2025 },
            CreateRow(12345) with { SubsidiaryId = "900002", RelativeYear = 2026 }
        };

        // Act
        var result = BillingOrganisationsBuilder.Build(rows, _mockLogger.Object);

        // Assert
        result.Should().ContainSingle().Which.SubsidiaryDetails
            .Select(x => x.SubsidiaryId).Should().Equal("900002");
    }

    private static PayCalLatestAcceptedGrantedOrg CreateRow(int organisationId) => new()
    {
        OrganisationId = organisationId,
        SubsidiaryId = null,
        RelativeYear = 2025,
        DecisionDate = "2025-06-01T00:00:00.0000000Z"
    };
}
