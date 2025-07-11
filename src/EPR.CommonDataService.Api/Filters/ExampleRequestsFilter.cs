using EPR.CommonDataService.Api.Controllers;
using Microsoft.OpenApi.Any;
using Microsoft.OpenApi.Models;
using Newtonsoft.Json;
using Swashbuckle.AspNetCore.SwaggerGen;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Filters
{
    [ExcludeFromCodeCoverage]
    public class ExampleRequestsFilter : IOperationFilter
    {
        public void Apply(OpenApiOperation operation, OperationFilterContext context)
        {
            OpenApiParameter? subIdParam = default;
            OpenApiParameter? beforeProducerParam = default;
            OpenApiParameter? lateFeeParam = default;
            var name = context.MethodInfo.Name;

            if (context.MethodInfo.Name == nameof(SubmissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters) ||
                context.MethodInfo.Name == nameof(SubmissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters))
            {
                subIdParam = operation.Parameters.First(p => p.Name == "submissionId");
                beforeProducerParam = operation.Parameters.First(p => p.Name == "beforeProducerSubmits");
                beforeProducerParam.Example = new OpenApiBoolean(false);

                lateFeeParam = operation.Parameters.First(p => p.Name == "lateFeeRules");

                lateFeeParam.Schema = new OpenApiSchema
                {
                    Type = "object",
                    Properties =
                {
                    ["LateFeeCutOffMonth_2025"] = new OpenApiSchema { Type = "string", Example = new OpenApiString("4") },
                    ["LateFeeCutOffDay_2025"]   = new OpenApiSchema { Type = "string", Example = new OpenApiString("1") },
                    ["LateFeeCutOffMonth_CS"]   = new OpenApiSchema { Type = "string", Example = new OpenApiString("10") },
                    ["LateFeeCutOffDay_CS"]     = new OpenApiSchema { Type = "string", Example = new OpenApiString("1") },
                    ["LateFeeCutOffMonth_SP"]   = new OpenApiSchema { Type = "string", Example = new OpenApiString("4") },
                    ["LateFeeCutOffDay_SP"]     = new OpenApiSchema { Type = "string", Example = new OpenApiString("1") },
                    ["LateFeeCutOffMonth_LP"]   = new OpenApiSchema { Type = "string", Example = new OpenApiString("10") },
                    ["LateFeeCutOffDay_LP"]     = new OpenApiSchema { Type = "string", Example = new OpenApiString("1") }
                },
                    AdditionalPropertiesAllowed = false,
                    Example = new OpenApiObject
                    {
                        ["LateFeeCutOffMonth_2025"] = new OpenApiString("4"),
                        ["LateFeeCutOffDay_2025"] = new OpenApiString("1"),
                        ["LateFeeCutOffMonth_CS"] = new OpenApiString("10"),
                        ["LateFeeCutOffDay_CS"] = new OpenApiString("1"),
                        ["LateFeeCutOffMonth_SP"] = new OpenApiString("4"),
                        ["LateFeeCutOffDay_SP"] = new OpenApiString("1"),
                        ["LateFeeCutOffMonth_LP"] = new OpenApiString("10"),
                        ["LateFeeCutOffDay_LP"] = new OpenApiString("1")
                    }
                };
                lateFeeParam.Style = ParameterStyle.DeepObject;
                lateFeeParam.Explode = true;
            }

            if (name == nameof(SubmissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters))
            {
                subIdParam.Example = null;
                // add two named examples
                subIdParam.Examples.Clear();
                subIdParam.Examples.Add("LargeProducer", new OpenApiExample
                {
                    Summary = "Large producer scenario",
                    Value = new OpenApiString("8a05f617-ebcf-486b-a92e-4131616a93bc")
                });
                subIdParam.Examples.Add("SmallProducer", new OpenApiExample
                {
                    Summary = "Small producer scenario",
                    Value = new OpenApiString("d7f173b5-108e-4e0a-9d3d-affaa2499ea8")
                });
            }
            else if (name == nameof(SubmissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters))
            {
                // Single example for the CSO endpoint
                subIdParam.Example = new OpenApiString("c8b7d333-ce94-46fb-8855-e335c4b135f2");
            }
        }
    }
}
