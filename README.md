# genAIPlatform

[x] create kubernetes service account

kubectl create serviceaccount llm
 
[x] create IAM policy for the account

gcloud projects add-iam-policy-binding projects/boris001 \
    --role=roles/container.clusterViewer \
    --member=principal://iam.googleapis.com/projects/745535691203/locations/global/workloadIdentityPools/boris001.svc.id.goog/subject/ns/dev/sa/llm \
    --condition=None

[x] service account with mininmal scope

[x] workload identity for pod

[x] add resource constraints

[ ] connect litellm to database

