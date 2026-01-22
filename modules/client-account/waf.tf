# =============================================================================
# WAF Web ACL - Disabled for HTTP API
# =============================================================================
# Note: WAF v2 cannot be directly associated with API Gateway HTTP API
# To add WAF protection, use CloudFront in front of API Gateway
# API Gateway has built-in throttling as an alternative
#
# The WAF resource has been commented out since we migrated from ALB to
# API Gateway HTTP API. If you need WAF protection, consider:
# 1. Adding CloudFront in front of API Gateway
# 2. Migrating to REST API (more expensive)
# 3. Using API Gateway throttling (already enabled)
