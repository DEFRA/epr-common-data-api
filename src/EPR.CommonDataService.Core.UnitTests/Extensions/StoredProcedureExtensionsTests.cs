using AutoFixture;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using System.Text.Json;

namespace EPR.CommonDataService.Core.UnitTests.Extensions;

[TestClass]
public class StoredProcedureExtensionsTests
{
    private IFixture _fixture;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();
    }

    [TestMethod]
    public void ToProcParams_ShouldReturnCorrectFormat_GivenAllPropertiesHaveValues()
    {
        // Arrange
        var request = _fixture.Create<SubmissionsSummariesRequest<RegulatorPomDecision>>();

        // Act
        var result = request.ToProcParams();

        // Assert
        result.Should().HaveCount(8);
        var organisationName = result.Single(x => x.ParameterName == "@OrganisationName");
        organisationName.Value.Should().Be(request.OrganisationName);
        var organisationReference = result.Single(x => x.ParameterName == "@OrganisationReference");
        organisationReference.Value.Should().Be(request.OrganisationReference);
        var regulatorUserId = result.Single(x => x.ParameterName == "@RegulatorUserId");
        regulatorUserId.Value.Should().Be(request.UserId.ToString());
        var statusesCommaSeperated = result.Single(x => x.ParameterName == "@StatusesCommaSeperated");
        statusesCommaSeperated.Value.Should().Be(request.Statuses);
        var organisationType = result.Single(x => x.ParameterName == "@OrganisationType");
        organisationType.Value.Should().Be(request.OrganisationType);
        var pageSize = result.Single(x => x.ParameterName == "@PageSize");
        pageSize.Value.Should().Be(request.PageSize);
        var pageNumber = result.Single(x => x.ParameterName == "@PageNumber");
        pageNumber.Value.Should().Be(request.PageNumber);
        var descisionDelta = result.Single(x => x.ParameterName == "@DecisionsDelta");
        descisionDelta.Value.Should().Be(JsonSerializer.Serialize(request.DecisionsDelta));
    }

    [TestMethod]
    public void ToProcParams_ShouldHandleNullDecisionsDelta()
    {
        // Arrange
        var request = _fixture
            .Build<SubmissionsSummariesRequest<RegulatorPomDecision>>()
            .With(x => x.DecisionsDelta, (RegulatorPomDecision[])null)
            .Create();

        // Act
        var result = request.ToProcParams();

        // Assert
        var descisionDelta = result.Single(x => x.ParameterName == "@DecisionsDelta");
        descisionDelta.Value.Should().Be("[]");
    }

    [TestMethod]
    public void ToProcParams_ShouldHandleEmptyArrayDecisionsDelta()
    {
        // Arrange
        var request = _fixture.Build<SubmissionsSummariesRequest<RegulatorPomDecision>>()
            .With(x => x.DecisionsDelta, new RegulatorPomDecision[]{})
            .Create();

        // Act
        var result = request.ToProcParams();

        // Assert
        var descisionDelta = result.Single(x => x.ParameterName == "@DecisionsDelta");
        descisionDelta.Value.Should().Be("[]");
    }
}
