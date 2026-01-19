# Diagram Design Best Practices

## Overview

This document defines the standards and best practices for creating professional architecture diagrams using the Python `diagrams` package. Following these guidelines ensures consistency, readability, and executive-ready presentations.

---

## 1. Color Palette

### Semantic Color System

Use colors consistently to convey meaning. Limit to 4-5 primary colors maximum.

| Color | Hex Code | Usage | Example |
|-------|----------|-------|---------|
| **Green** | `#2E7D32` | Allowed actions, success, permitted flows | User invoking agent |
| **Red** | `#C62828` | Blocked, denied, security alerts | Unauthorized access attempts |
| **Blue** | `#1565C0` | Normal data flow, internal operations | Data moving between services |
| **Orange** | `#E65100` | Cross-account, external, trust relationships | AssumeRole operations |
| **Gray** | `#757575` | Secondary flows, optional, metadata | Archive operations |

### Cluster Background Colors

Use subtle, pastel backgrounds for clusters. High saturation backgrounds compete with icons.

| Purpose | Hex Code | Description |
|---------|----------|-------------|
| Client Account | `#E3F2FD` | Very light blue |
| Central Account | `#FFF3E0` | Very light orange |
| Security/Protected | `#FFEBEE` | Very light red |
| Success/Allowed | `#E8F5E9` | Very light green |
| Monitoring | `#FFF8E1` | Very light amber |
| Neutral | `#F5F5F5` | Very light gray |

### What to Avoid

- **Too many colors**: More than 5 primary colors creates visual noise
- **High saturation backgrounds**: Competes with icons for attention
- **Inconsistent meaning**: Don't use red for success or green for errors
- **Pink/Magenta**: Feels less professional for enterprise diagrams

---

## 2. Typography & Labels

### Label Guidelines

| Rule | Good Example | Bad Example |
|------|--------------|-------------|
| Max 3-4 words | "Encrypted Prompts" | "SSM Parameter Store with Encrypted Prompts" |
| No account IDs | "Client Account" | "Client Account (875228160179)" |
| Consistent case | "Bedrock Agent" | "bedrock agent" or "BEDROCK AGENT" |
| Known abbreviations only | "KMS", "IAM", "S3" | "EB" (use "EventBridge") |

### Icon Labels

```python
# GOOD - Concise
kms = KMS("KMS Key")
ssm = SSM("Encrypted Prompts")
agent = Bedrock("Bedrock Agent")

# BAD - Too verbose
kms = KMS("AWS Key Management Service Customer Managed Key")
ssm = SSM("AWS Systems Manager Parameter Store SecureString")
```

### Multi-line Labels

Use `\n` for multi-line labels when needed, but limit to 2 lines:

```python
# GOOD - Clear hierarchy
ssm = SSM("Encrypted\nPrompts")

# BAD - Too many lines
ssm = SSM("AWS SSM\nParameter Store\nSecureString\nEncrypted")
```

---

## 3. Layout & Direction

### Choosing Direction

| Direction | Best For | Example |
|-----------|----------|---------|
| `LR` (Left-to-Right) | Data flows, request/response | User → Service → Database |
| `TB` (Top-to-Bottom) | Hierarchies, layers, stacks | Security layers, org charts |
| `RL` (Right-to-Left) | Rarely used | Avoid unless culturally appropriate |
| `BT` (Bottom-to-Top) | Rarely used | Building up from foundation |

### Graph Attributes

```python
graph_attr = {
    "fontsize": "18",        # Title font size
    "bgcolor": "white",      # Background color
    "pad": "0.5",            # Padding around diagram
    "nodesep": "0.8",        # Horizontal spacing between nodes
    "ranksep": "1.0",        # Vertical spacing between ranks
    "splines": "ortho"       # Line style: ortho, polyline, curved
}
```

### Spline Options

| Value | Description | Best For |
|-------|-------------|----------|
| `ortho` | Right-angle lines | Clean, architectural diagrams |
| `polyline` | Straight lines with corners | Simple flows |
| `spline` | Curved lines | Organic, complex relationships |
| `false` | Straight lines only | Minimal diagrams |

---

## 4. Edges & Arrows

### Edge Styling

```python
# Primary flow - Bold, colored
Edge(color="#2E7D32", penwidth="2.5", label="InvokeAgent")

# Secondary flow - Normal weight
Edge(color="#1565C0", penwidth="1.5")

# Blocked/Denied - Dashed red
Edge(color="#C62828", style="dashed", label="DENIED")

# Optional/Background - Dotted gray
Edge(color="#757575", style="dotted")
```

### Edge Attributes

| Attribute | Values | Usage |
|-----------|--------|-------|
| `color` | Hex code | Semantic meaning |
| `penwidth` | "1.0" to "3.0" | Importance (thicker = more important) |
| `style` | "solid", "dashed", "dotted", "bold" | Flow type |
| `label` | String | Only when necessary |

### Label Guidelines for Edges

- **DO** label primary flows and critical actions
- **DO** label denied/blocked flows
- **DON'T** label every edge (creates clutter)
- **DON'T** use verbose labels ("This connection allows the user to invoke the agent")

```python
# GOOD - Concise labels
customer >> Edge(label="InvokeAgent") >> agent
customer >> Edge(label="DENIED", style="dashed") >> ssm

# BAD - Over-labeled
customer >> Edge(label="User invokes the Bedrock agent using InvokeAgent API") >> agent
```

---

## 5. Clusters

### Nesting Rules

- **Maximum 2-3 levels** of nesting
- **Group by logical function**, not just location
- **Use consistent background colors** for similar cluster types

```python
# GOOD - Clear hierarchy (2 levels)
with Cluster("Client Account"):
    with Cluster("Protected Storage"):
        kms = KMS("KMS Key")
        ssm = SSM("Prompts")

# BAD - Too deep (4+ levels)
with Cluster("AWS"):
    with Cluster("Client Account"):
        with Cluster("Region us-east-1"):
            with Cluster("VPC"):
                with Cluster("Private Subnet"):
                    service = EC2("Service")
```

### Cluster Styling

```python
# Account-level clusters
with Cluster("Client Account", graph_attr={
    "bgcolor": "#E3F2FD",
    "style": "rounded",
    "fontsize": "16"
}):

# Sub-clusters (lighter, no border emphasis)
with Cluster("Protected Storage", graph_attr={
    "bgcolor": "#FFEBEE",
    "fontsize": "12"
}):
```

---

## 6. Executive Presentation Guidelines

### The 30-Second Rule

An executive should understand the main message in 30 seconds:

1. **One clear focal point** - What's the main thing?
2. **Color-coded meaning** - Green = good, Red = bad
3. **Minimal text** - Icons speak louder than labels
4. **Clear flow direction** - Left to right, top to bottom

### Simplification Strategies

| Full Diagram | Executive Version |
|--------------|-------------------|
| All 4 EventBridge rules | Single "Detection Rules" icon |
| All IAM roles detailed | Single "IAM Controls" cluster |
| All services listed | Only key services (3-5 max) |
| Technical labels | Business labels |

### Executive Overview Template

```python
with Diagram("Solution Overview", show=False, direction="LR"):
    user = User("Customer")

    with Cluster("Protected Environment"):
        service = Bedrock("AI Agent")
        protection = Shield("IP Protection")

    owner = User("You")

    user >> Edge(color="#2E7D32", penwidth="3", label="USE") >> service
    user >> Edge(color="#C62828", style="dashed", label="NO ACCESS") >> protection
    owner >> Edge(color="#E65100", penwidth="3", label="CONTROL") >> protection
```

---

## 7. Common Patterns

### Multi-Account Architecture

```python
with Diagram("Multi-Account", direction="TB"):

    with Cluster("Account A", graph_attr={"bgcolor": "#E3F2FD"}):
        service_a = Lambda("Service A")

    with Cluster("Account B", graph_attr={"bgcolor": "#FFF3E0"}):
        service_b = Lambda("Service B")

    service_a >> Edge(color="#E65100", label="Cross-Account") >> service_b
```

### Security Flow (Allowed vs Denied)

```python
user = User("User")
allowed = Lambda("Allowed Action")
denied = Lambda("Denied Action")

user >> Edge(color="#2E7D32", label="Allowed") >> allowed
user >> Edge(color="#C62828", style="dashed", label="DENIED") >> denied
```

### Monitoring & Alerting

```python
with Cluster("Monitoring"):
    trail = Cloudtrail("Audit")
    rules = Eventbridge("Detection")
    alerts = SNS("Alerts")

    trail >> Edge(color="#1565C0") >> rules
    rules >> Edge(color="#C62828", label="Alert") >> alerts
```

---

## 8. Checklist Before Finalizing

### Content Review
- [ ] Main message clear in 30 seconds?
- [ ] No account IDs in labels?
- [ ] Labels are 3-4 words max?
- [ ] Only known abbreviations used?

### Color Review
- [ ] Max 4-5 primary colors used?
- [ ] Colors have consistent semantic meaning?
- [ ] Cluster backgrounds are subtle/pastel?
- [ ] Sufficient contrast for readability?

### Layout Review
- [ ] Appropriate direction for content type?
- [ ] Max 2-3 cluster nesting levels?
- [ ] No overlapping elements?
- [ ] Balanced visual composition?

### Edge Review
- [ ] Primary flows are bold/thick?
- [ ] Denied flows use dashed red?
- [ ] Only essential edges are labeled?
- [ ] No crossing lines where avoidable?

### Executive Readiness
- [ ] Would a CEO understand in 30 seconds?
- [ ] Key message is immediately visible?
- [ ] Technical jargon minimized?
- [ ] Professional color scheme?

---

## 9. Template: Standard Architecture Diagram

```python
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.ml import Bedrock
from diagrams.aws.security import KMS, IAMRole, SecretsManager
from diagrams.aws.management import SSM, Cloudtrail
from diagrams.aws.integration import Eventbridge, SNS
from diagrams.aws.storage import S3
from diagrams.aws.compute import Lambda
from diagrams.aws.general import User

# Color constants
GREEN = "#2E7D32"   # Allowed
RED = "#C62828"     # Blocked
BLUE = "#1565C0"    # Data flow
ORANGE = "#E65100"  # Cross-account
GRAY = "#757575"    # Secondary

# Cluster backgrounds
CLIENT_BG = "#E3F2FD"
CENTRAL_BG = "#FFF3E0"
SECURITY_BG = "#FFEBEE"
SUCCESS_BG = "#E8F5E9"

with Diagram(
    "Architecture Name",
    show=False,
    direction="LR",
    graph_attr={
        "fontsize": "18",
        "bgcolor": "white",
        "pad": "0.5",
        "nodesep": "0.8",
        "ranksep": "1.0"
    }
):
    # External actors
    customer = User("Customer")
    admin = User("Admin")

    # Client environment
    with Cluster("Client Account", graph_attr={"bgcolor": CLIENT_BG, "style": "rounded"}):
        with Cluster("Core Service", graph_attr={"bgcolor": SUCCESS_BG}):
            service = Bedrock("Service")

        with Cluster("Security", graph_attr={"bgcolor": SECURITY_BG}):
            kms = KMS("Encryption")
            data = SSM("Protected Data")

    # Central environment
    with Cluster("Central Account", graph_attr={"bgcolor": CENTRAL_BG, "style": "rounded"}):
        management = IAMRole("Management")
        alerts = SNS("Alerts")

    # Flows
    customer >> Edge(color=GREEN, penwidth="2.5", label="Use") >> service
    customer >> Edge(color=RED, style="dashed", label="DENIED") >> data
    admin >> Edge(color=ORANGE, penwidth="2.0", label="Manage") >> management
    management >> Edge(color=ORANGE) >> data
```

---

## 10. Resources

### Official Documentation
- [Python Diagrams Package](https://diagrams.mingrammer.com/)
- [Graphviz Attributes](https://graphviz.org/doc/info/attrs.html)

### Color Tools
- [Material Design Colors](https://materialui.co/colors/)
- [Coolors Palette Generator](https://coolors.co/)
- [Color Contrast Checker](https://webaim.org/resources/contrastchecker/)

### AWS Icons
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
