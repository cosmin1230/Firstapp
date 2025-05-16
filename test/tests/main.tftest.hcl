variables {
  vpc_name       = "test-vpc"
  vpc_cidr_block = "10.0.0.0/16"
  az_count       = 2
}

# 1. SCENARIO: Both Subnets Enabled
run "plan_both_subnets_enabled" {
  command = plan

  variables {
    enable_public_subnets  = true
    enable_private_subnets = true
  }
}

# 2. SCENARIO: Public Subnets Only
run "plan_public_subnets_only" {
  command = plan

  variables {
    enable_public_subnets  = true
    enable_private_subnets = false
  }
}

# 3. SCENARIO: Private Subnets Only
run "plan_private_subnets_only" {
  command = plan

  variables {
    enable_public_subnets  = false
    enable_private_subnets = true
  }
}

# 4. SCENARIO: Both Subnets Disabled
run "plan_no_subnets" {
  command = plan

  variables {
    enable_public_subnets  = false
    enable_private_subnets = false
  }
}