# =============================================================================
# AWS WAF - Web Application Firewall
# =============================================================================
# Protects ALB with:
# - Rate limiting per IP
# - AWS Managed Rule Sets (common attacks, known bad inputs)
# - SQL injection protection
# - XSS protection
# =============================================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf"
  description = "WAF for protected agent ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # =================================================================
  # Rule 1: Rate Limiting
  # =================================================================
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # =================================================================
  # Rule 2: AWS Managed Rules - Common Rule Set
  # =================================================================
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # =================================================================
  # Rule 3: AWS Managed Rules - Known Bad Inputs
  # =================================================================
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # =================================================================
  # Rule 4: AWS Managed Rules - SQL Injection
  # =================================================================
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # =================================================================
  # Rule 5: Block Prompt Injection Patterns
  # =================================================================
  rule {
    name     = "BlockPromptInjection"
    priority = 5

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            field_to_match {
              body {
                oversize_handling = "MATCH"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = "ignore previous instructions"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            field_to_match {
              body {
                oversize_handling = "MATCH"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = "ignore all instructions"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            field_to_match {
              body {
                oversize_handling = "MATCH"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = "system prompt"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            field_to_match {
              body {
                oversize_handling = "MATCH"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = "reveal your"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            field_to_match {
              body {
                oversize_handling = "MATCH"
              }
            }
            positional_constraint = "CONTAINS"
            search_string         = "jailbreak"
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-prompt-injection"
      sampled_requests_enabled   = true
    }
  }

  # =================================================================
  # Rule 6: Request Size Limit (prevent large payloads)
  # =================================================================
  rule {
    name     = "RequestSizeLimit"
    priority = 6

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {
            oversize_handling = "MATCH"
          }
        }
        comparison_operator = "GT"
        size                = 10000 # 10KB max request body
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-size-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.default_tags
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 30

  tags = local.default_tags
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}
