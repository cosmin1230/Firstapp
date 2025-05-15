#!/bin/bash

set -e

echo "Running all Terraform plan test scenarios..."
echo

# List of variable combinations to test
TEST_CASES=(
  "enable_public_subnets=true enable_private_subnets=true az_count=1"  # Test single AZ
  "enable_public_subnets=true enable_private_subnets=true az_count=2" # Test multiple AZs
  "enable_public_subnets=true enable_private_subnets=false az_count=2" # Test public subnets only
  "enable_public_subnets=false enable_private_subnets=true az_count=2" # Test private subnets only
  "enable_public_subnets=false enable_private_subnets=false az_count=1" # Test no subnets in a single AZ
  "enable_public_subnets=false enable_private_subnets=false az_count=2" # Test no subnets in multiple AZs
)

for i in "${!TEST_CASES[@]}"; do
  echo "-----------------------------"
  echo "Test $((i+1)): ${TEST_CASES[$i]}"

  terraform init -input=false -upgrade > /dev/null

  # Build -var flags dynamically
  VARS=""
  for var in ${TEST_CASES[$i]}; do
    VARS="$VARS -var $var"
  done

  # Add static vars (like CIDR and VPC name)
  VARS="$VARS -var vpc_name=test-vpc-$i -var vpc_cidr_block=10.$i.0.0/16"

  # Run terraform plan with all vars
  if terraform plan -input=false $VARS ; then
    echo " Test $((i+1)) passed."
  else
    echo " Test $((i+1)) failed."
    exit 1
  fi

  echo
done

echo " All plan tests completed successfully."
