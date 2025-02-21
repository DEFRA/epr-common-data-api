using AutoFixture;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Data.Entities;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.UnitTests.Extensions;

[ExcludeFromCodeCoverage]
public class PaginatedResponseExtensionsTests
{
    private Fixture _fixture = null!;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();
    }

    [TestMethod]
    public void ToPaginatedResponse_FirstPage_ShouldSetItemsCorrectly()
    {
        // Arrange
        var rows = _fixture
            .Build<PomSubmissionSummaryRow>()
            .With(x => x.TotalItems, 100)
            .CreateMany(10).ToArray();
        var request = _fixture
            .Build<SubmissionsSummariesRequest<RegulatorPomDecision>>()
            .With(x => x.PageSize, 10)
            .With(x => x.PageNumber, 1)
            .Create();

        // Act
        var response = rows.ToPaginatedResponse<PomSubmissionSummaryRow,RegulatorPomDecision,PomSubmissionSummary>(request, 100);

        // Assert
        response.Items.Should().HaveCount(10);
        response.TotalItems.Should().Be(100);
        response.Items.Should().BeEquivalentTo(rows.OfType<PomSubmissionSummary>());
    }

    [TestMethod]
    public void ToPaginatedResponse_ShouldSetTotalItemsToZeroIfNoRows()
    {
        // Arrange
        var request = new SubmissionsSummariesRequest<RegulatorPomDecision>
        {
            PageNumber = 1,
            PageSize = 10
        };

        // Act
        var response = new List<PomSubmissionSummaryRow>().ToPaginatedResponse<PomSubmissionSummaryRow,RegulatorPomDecision,PomSubmissionSummary>(request, 10);

        // Assert
        response.TotalItems.Should().Be(0);
    }
}