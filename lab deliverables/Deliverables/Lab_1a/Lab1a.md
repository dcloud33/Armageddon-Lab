2. Short answers:
 A) Why is DB inbound source restricted to the EC2 security group?
 Answer: The DB inbound source is restricted to the EC2, that is able to connect to the DB. This also keeps it private making it secure and allowing to keep traffic only between EC2 and RDS
  B) What port does MySQL use?
  Answer:3306
  C) Why is Secrets Manager better than storing creds in code/user-data?
  Answer: Secrets Manager is better choice due to the fact that it keeps your passwords from being hard coded and gets rid of it being easily exposed. 

  Why each rule exists?
  Answer:
  Why broader access is forbidden?
  Answer: By limiting the access it keeps anyone who shouldn't be working in areas that they're not allowed. When you imnplement least priveleges it maintains a better structure of checks and balances.
  Why this role exists?
  Answer: In order to give the ec2 instance the ability to communicate with rds instance and by using least priveleges it keeps it solely for that rds instance.
  Why it can read this secret?
  Answer: It can read this secret because of the policies that are attached to the role that was attached for the ec2 instance. Which gave it read access for the secrets that were stored.
  Why it cannot read others?
  Answer: It can't read others because the least priveleges points only to the secrets manager secret ID that was associated with the inline policy. This would keep it from reading any other secret.