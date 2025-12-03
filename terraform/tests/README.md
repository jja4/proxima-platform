# Terraform Tests

This directory contains Terraform native tests for validating infrastructure configuration.

## Running Tests

```bash
# Navigate to the terraform directory
cd terraform

# Run all tests
terraform test

# Run specific test file
terraform test -filter=tests/platform_test.tftest.hcl

# Run with verbose output
terraform test -verbose
```

## Test Structure

```
tests/
├── ml-platform_test.tftest.hcl    # Main ml-platform tests
│   ├── VPC Tests               # Network configuration
│   ├── GKE Tests               # Cluster configuration
│   └── Integration Tests       # Full environment validation
```

## Test Categories

### VPC Tests
- `vpc_network_creation` - Validates VPC network naming and configuration
- `vpc_subnet_configuration` - Validates subnet CIDR and secondary ranges
- `vpc_nat_configuration` - Validates Cloud NAT setup

### GKE Tests
- `gke_cluster_configuration` - Validates cluster settings
- `gke_cpu_node_pool` - Validates CPU node pool autoscaling and machine types
- `gke_workload_identity_enabled` - Validates Workload Identity configuration
- `gke_gpu_pool_disabled_by_default` - Validates GPU pool is opt-in
- `gke_gpu_pool_enabled` - Validates GPU pool when enabled

### Integration Tests
- `dev_environment_validates` - Full environment validation

## Adding New Tests

1. Create assertions in the appropriate `run` block:

```hcl
run "my_new_test" {
  command = plan

  module {
    source = "../modules/my_module"
  }

  variables {
    # Test variables
  }

  assert {
    condition     = my_resource.name == "expected-value"
    error_message = "Description of what went wrong"
  }
}
```

2. Run tests to verify:
```bash
terraform test
```

## CI Integration

Tests are automatically run in the GitHub Actions workflow on:
- Pull requests to `main` branch
- Changes to `terraform/**` files

See `.github/workflows/terraform.yml` for CI configuration.
