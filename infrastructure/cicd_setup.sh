#!/bin/bash
# ================================================================
# CI/CD Setup — CodePipeline + CodeBuild + CodeCommit
# Auto-deploys Glue scripts on every git push to main branch
# Region: eu-north-1  |  Account: 430006376054
# ================================================================

REGION="eu-north-1"
ACCOUNT_ID="430006376054"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/dms-s3-target-role-bdclp"
REPO_NAME="data-pipeline-bdclp"
BUILD_PROJECT="pipeline-build-bdclp"
PIPELINE_NAME="data-pipeline-cicd-bdclp"
ARTIFACT_BUCKET="my-pipeline-scripts-bdclp"

# ── 1. Create CodeCommit repository ──────────────────────────────
aws codecommit create-repository \
  --repository-name $REPO_NAME \
  --repository-description "AWS end-to-end data pipeline codebase" \
  --region $REGION

# ── 2. Create CodeBuild project ───────────────────────────────────
aws codebuild create-project \
  --name $BUILD_PROJECT \
  --source "{
    \"type\": \"CODECOMMIT\",
    \"location\": \"https://git-codecommit.${REGION}.amazonaws.com/v1/repos/${REPO_NAME}\"
  }" \
  --artifacts '{"type": "NO_ARTIFACTS"}' \
  --environment '{
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/standard:7.0",
    "computeType": "BUILD_GENERAL1_SMALL"
  }' \
  --service-role $ROLE_ARN \
  --logs-config "{
    \"cloudWatchLogs\": {
      \"status\": \"ENABLED\",
      \"groupName\": \"pipeline-build-logs-bdclp\"
    }
  }" \
  --region $REGION

# ── 3. Create CodePipeline ────────────────────────────────────────
aws codepipeline create-pipeline \
  --pipeline "{
    \"name\": \"${PIPELINE_NAME}\",
    \"roleArn\": \"${ROLE_ARN}\",
    \"artifactStore\": {
      \"type\": \"S3\",
      \"location\": \"${ARTIFACT_BUCKET}\"
    },
    \"stages\": [
      {
        \"name\": \"Source\",
        \"actions\": [{
          \"name\": \"Source\",
          \"actionTypeId\": {
            \"category\": \"Source\",
            \"owner\": \"AWS\",
            \"provider\": \"CodeCommit\",
            \"version\": \"1\"
          },
          \"configuration\": {
            \"RepositoryName\": \"${REPO_NAME}\",
            \"BranchName\": \"main\",
            \"PollForSourceChanges\": \"true\"
          },
          \"outputArtifacts\": [{\"name\": \"SourceOutput\"}]
        }]
      },
      {
        \"name\": \"Build\",
        \"actions\": [{
          \"name\": \"Build\",
          \"actionTypeId\": {
            \"category\": \"Build\",
            \"owner\": \"AWS\",
            \"provider\": \"CodeBuild\",
            \"version\": \"1\"
          },
          \"configuration\": {\"ProjectName\": \"${BUILD_PROJECT}\"},
          \"inputArtifacts\": [{\"name\": \"SourceOutput\"}]
        }]
      }
    ]
  }" \
  --region $REGION

echo "CI/CD pipeline created."
echo "Pipeline: ${PIPELINE_NAME}"
echo "Push code to CodeCommit main branch to trigger auto-deployment."
