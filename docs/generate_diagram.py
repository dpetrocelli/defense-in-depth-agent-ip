#!/usr/bin/env python3
"""Generate AWS architecture diagram for the blog post."""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS, Lambda, ECR
from diagrams.aws.network import ALB, APIGateway
from diagrams.aws.security import SecretsManager, KMS, WAF
from diagrams.aws.management import Cloudwatch

# Graph attributes for better layout
graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "ortho",
}

with Diagram(
    "Bedrock Protected Mode - First Attempt",
    filename="docs/diagram_first_attempt",
    show=False,
    direction="LR",
    outformat="svg",
    graph_attr=graph_attr,
):
    with Cluster("Central Account (Your Control)"):
        secrets = SecretsManager("Prompts\n(encrypted)")
        kms = KMS("CMK")
        secrets - Edge(style="dashed") - kms

    with Cluster("Client Account"):
        ecs = ECS("ECS Task\n(your code)")
        task_role = Lambda("Task Role")  # Using Lambda icon as placeholder
        ecs - task_role

    task_role >> Edge(label="AssumeRole\n+ GetSecretValue", color="red", style="dashed") >> secrets


with Diagram(
    "Bedrock Protected Mode - Final Solution",
    filename="docs/diagram_final_solution",
    show=False,
    direction="LR",
    outformat="svg",
    graph_attr=graph_attr,
):
    with Cluster("Central Account (Your Control)"):
        ecr = ECR("ECR\n(your image)")

        with Cluster("Gatekeeper"):
            apigw = APIGateway("API Gateway")
            gatekeeper = Lambda("Lambda\nGatekeeper")
            apigw >> gatekeeper

        secrets = SecretsManager("Prompts")
        kms = KMS("CMK")

        gatekeeper >> secrets
        secrets - Edge(style="dashed") - kms

    with Cluster("Client Account"):
        waf = WAF("WAF")
        alb = ALB("ALB")
        ecs = ECS("ECS Fargate\n(signing key\nembedded)")
        cw = Cloudwatch("CloudTrail\nAlerts")

        waf >> alb >> ecs
        ecs >> Edge(style="dashed", color="orange") >> cw

    # Cross-account flows
    ecr >> Edge(label="pull image", style="dashed") >> ecs
    ecs >> Edge(label="HMAC signed\nrequest", color="darkgreen") >> apigw


print("Diagrams generated successfully!")
print("- docs/diagram_first_attempt.svg")
print("- docs/diagram_final_solution.svg")
