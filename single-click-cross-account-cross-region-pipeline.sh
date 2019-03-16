#!/usr/bin/env bash
#echo -n "Enter ToolsAccount > "
#read ToolsAccount
ToolsAccount=924474025577
#echo -n "Enter ToolsAccount ProfileName for AWS Cli operations> "
#read ToolsAccountProfile
ToolsAccountProfile="default"
#echo -n "Enter Dev Account > "
#read DevAccount
DevAccount=924474025577
#echo -n "Enter DevAccount ProfileName for AWS Cli operations> "
#read DevAccountProfile
DevAccountProfile="default"
#echo -n "Enter Test Account > "
#read TestAccount
TestAccount=694337658763
#echo -n "Enter TestAccount ProfileName for AWS Cli operations> "
#read TestAccountProfile
TestAccountProfile="crossaccount"
#echo -n "Enter Prod Account > "
#read ProdAccount
ProdAccount=694337658763
#echo -n "Enter ProdAccount ProfileName for AWS Cli operations> "
#read ProdAccountProfile
ProdAccountProfile=crossaccount

aws cloudformation deploy --stack-name pre-reqs-ca --template-file ToolsAcct/pre-reqs-a.yaml --parameter-overrides DevAccount=$DevAccount TestAccount=$TestAccount ProductionAccount=$ProdAccount --profile $ToolsAccountProfile
S3Bucket=$(aws cloudformation --profile $ToolsAccountProfile describe-stacks --stack-name pre-reqs-ca 2>&1 | tee pre-reqs-ca-outpus.json | jq -r '.Stacks[0].Outputs[1].OutputValue')
CMKArn=$(aws cloudformation --profile $ToolsAccountProfile describe-stacks --stack-name pre-reqs-ca 2>&1 | tee pre-reqs-ca-outpus.json | jq -r '.Stacks[0].Outputs[0].OutputValue')

aws cloudformation deploy --stack-name pre-reqs-ca --template-file ToolsAcct/pre-reqs-b.yaml --parameter-overrides DevAccount=$DevAccount TestAccount=$TestAccount ProductionAccount=$ProdAccount --profile $TestAccountProfile
S3BucketB=$(aws cloudformation --profile $TestAccountProfile describe-stacks --stack-name pre-reqs-ca 2>&1 | tee pre-reqs-ca-b-outpus.json | jq -r '.Stacks[0].Outputs[0].OutputValue')

#echo -n "Enter S3 Bucket created from above > "
#read S3Bucket

#echo -n "Enter CMK ARN created from above > "
#read CMKArn

echo -n "Executing in DEV Account"
aws cloudformation deploy --stack-name toolsacct-codepipeline-role-ca --template-file DevAccount/toolsacct-codepipeline-codecommit.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ToolsAccount=$ToolsAccount TestAccount=$TestAccount CMKARN=$CMKArn --profile $DevAccountProfile

echo -n "Executing in TEST Account"
aws cloudformation deploy --stack-name toolsacct-codepipeline-cloudformation-role-ca --template-file TestAccount/toolsacct-codepipeline-cloudformation-deployer.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ToolsAccount=$ToolsAccount TestAccount=$TestAccount CMKARN=$CMKArn  S3Bucket=$S3Bucket S3BucketB=$S3BucketB --profile $TestAccountProfile

##echo -n "Executing in PROD Account"
##aws cloudformation deploy --stack-name toolsacct-codepipeline-cloudformation-role-ca --template-file TestAccount/toolsacct-codepipeline-cloudformation-deployer.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides ToolsAccount=$ToolsAccount CMKARN=$CMKArn  S3Bucket=$S3Bucket S3BucketB=$S3BucketB --profile $ProdAccountProfile

echo -n "Creating Pipeline in Tools Account"
aws cloudformation deploy --stack-name sample-lambda-pipeline-ca --template-file ToolsAcct/code-pipeline.yaml --parameter-overrides DevAccount=$DevAccount TestAccount=$TestAccount ProductionAccount=$ProdAccount CMKARN=$CMKArn S3Bucket=$S3Bucket S3BucketB=$S3BucketB --capabilities CAPABILITY_NAMED_IAM --profile $ToolsAccountProfile

CBArn=$(aws cloudformation --profile $ToolsAccountProfile describe-stacks --stack-name sample-lambda-pipeline-ca 2>&1 | tee sample-lambda-pipeline-ca.json | jq -r '.Stacks[0].Outputs[0].OutputValue')

echo -n "Setting policy in Bucket B in TEST Account"
aws cloudformation deploy --stack-name bucketb-policy --template-file TestAccount/bucketb-policy.yaml --parameter-overrides DevAccount=$DevAccount TestAccount=$TestAccount ProductionAccount=$ProdAccount CMKARN=$CMKArn S3Bucket=$S3Bucket S3BucketB=$S3BucketB BuildProjectRoleArn=$CBArn --capabilities CAPABILITY_NAMED_IAM --profile $TestAccountProfile

#echo -n "Adding Permissions to the CMK"
#aws cloudformation deploy --stack-name pre-reqs-ca --template-file ToolsAcct/pre-reqs-a.yaml --parameter-overrides CodeBuildCondition=true --profile $ToolsAccountProfile
#aws cloudformation deploy --stack-name pre-reqs-ca --template-file ToolsAcct/pre-reqs-b.yaml --parameter-overrides CodeBuildCondition=true --profile $TestAccountProfile

echo -n "Adding Permissions to the Cross Accounts"
aws cloudformation deploy --stack-name sample-lambda-pipeline-ca --template-file ToolsAcct/code-pipeline.yaml --parameter-overrides CrossAccountCondition=true --capabilities CAPABILITY_NAMED_IAM --profile $ToolsAccountProfile

#Cleanup
#aws cloudformation delete-stack --stack-name toolsacct-codepipeline-role-ca --profile $DevAccountProfile
#aws cloudformation delete-stack --stack-name pre-reqs-ca --profile $ProdAccountProfile 
#aws cloudformation delete-stack --stack-name pre-reqs-ca --profile $ToolsAccountProfile 