public class RollupServices {
    public static List<SObject> filterUpdatedRollupFieldRecords(List<Sobject> newSobjects, Map<Id, Sobject> oldSobjects, String triggerObjectName){
        //TO DO Add filter logic
        return newSobjects;
    }
    /*public static Map<String, LREngine.RollupOperation> nameToRollupOperation
{
get
{
// lazy load pattern:
if (nameToRollupOperation == null)
{
//instantiation logic outlined above
Map<String, LREngine.RollupOperation> nameToRollupOperation = new Map<String, LREngine.RollupOperation>();
system.debug('LREngine.RollupOperation.values() '+LREngine.RollupOperation.values());
for (LREngine.RollupOperation enumValue : LREngine.RollupOperation.values())
{
nameToRollupOperation.put(String.valueOf(enumValue).toUpperCase(), enumValue);
}
system.debug('nameToRollupOperation 1'+nameToRollupOperation);
}
system.debug('nameToRollupOperation 2'+nameToRollupOperation);
return nameToRollupOperation;
}
private set;
}*/
    public static LREngine.RollupOperation getRollupOperation(String name)
    {
        Map<String, LREngine.RollupOperation> nameToRollupOperation = new Map<String, LREngine.RollupOperation>();
        system.debug('LREngine.RollupOperation.values() '+LREngine.RollupOperation.values());
        for (LREngine.RollupOperation enumValue : LREngine.RollupOperation.values())
        {
            nameToRollupOperation.put(String.valueOf(enumValue).toUpperCase(), enumValue);
        }
        system.debug('nameToRollupOperation '+nameToRollupOperation);
        return String.isBlank(name) ? null : nameToRollupOperation.get(name.toUpperCase());
    }
    public static void doRollup(List<Sobject> detailRecordsFromTrigger, String triggerObjectName){
        
        List<Sobject> masterSobjects = new List<Sobject>();
        for(Rollup_Object_Mapping__mdt rollupObjMapping :
            [Select id, Child_Object_Name__c, Lookup_Relationship_Field_API_Name__c, Parent_Object_Name__c
             from Rollup_Object_Mapping__mdt where Child_Object_Name__c =: triggerObjectName]){
                 system.debug('rollupObjMapping '+ rollupObjMapping);
                 Schema.SObjectType childObjType = Schema.getGlobalDescribe().get(rollupObjMapping.Child_Object_Name__c);
                 Schema.SObjectType parentObjType = Schema.getGlobalDescribe().get(rollupObjMapping.Parent_Object_Name__c);
                 //First step is to create a context for LREngine, by specifying parent and child objects and
                 //lookup relationship field name
                 Map<String, Schema.SobjectField> childFieldResult = childObjType.getDescribe().fields.getMap();
                 Map<String, Schema.SobjectField> parentFieldResult = parentObjType.getDescribe().fields.getMap();
                 Schema.DescribeFieldResult lookup_Relationship_Field = 
                     childFieldResult.get(rollupObjMapping.Lookup_Relationship_Field_API_Name__c).getDescribe();
                 LREngine.Context ctx = new LREngine.Context(parentObjType, // parent object
                                                             childObjType,  // child object
                                                             lookup_Relationship_Field // relationship field name
                                                            ); 
                 for(Rollup_Field_Mapping__mdt rollupFieldMapping: [Select Field_to_Aggregate__c, Operation__c, Parent_Field_to_store_aggregate_value__c 
                                                                    from Rollup_Field_Mapping__mdt where Rollup_Object_Mapping__c =: rollupObjMapping.Id]){
                                                                        //Next, one can add multiple rollup fields on the above relationship. 
                                                                        //Here specify 
                                                                        //1. The field to aggregate in child object
                                                                        //2. The field to which aggregated value will be saved in master/parent object
                                                                        //3. The aggregate operation to be done i.e. SUM, AVG, COUNT, MIN/MAX
                                                                        Schema.DescribeFieldResult Field_to_AggregateResult = childFieldResult.get(rollupFieldMapping.Field_to_Aggregate__c).getDescribe();
                                                                        Schema.DescribeFieldResult Parent_Field_to_store_aggregate_valueResult = childFieldResult.get(rollupFieldMapping.Parent_Field_to_store_aggregate_value__c).getDescribe();                     
                                                                        ctx.add(
                                                                            new LREngine.RollupSummaryField(
                                                                                Field_to_AggregateResult,Parent_Field_to_store_aggregate_valueResult,
                                                                                getRollupOperation(rollupFieldMapping.Operation__c) 
                                                                            )); 
                                                                    }
                 //Calling rollup method returns in memory master objects with aggregated values in them. 
                 //Please note these master records are not persisted back, so that client gets a chance 
                 //to post process them after rollup 
                 Sobject[] masters = LREngine.rollUp(ctx, detailRecordsFromTrigger);
                 if(masters != null)masterSobjects.addAll(masters);    
             }
        system.debug('masterSobjects '+masterSobjects);
        // Persiste the changes in master
        if(!masterSobjects.isEmpty())
            update masterSobjects;
    }
    /*
    public static void doRollup(List<Sobject> newSobjects, Map<Id, Sobject> oldSobjects, String triggerObjectName){
        //, StoreSummarizedValueAccountFieldApiName__c, StoreSummarizedValueUserFieldApiName__c/
        // Lets match the api names if possible;
        Account_User_Rollup_Relationship_Mapping__mdt rollupMapping = 
            [Select id, Account_Lookup_Field_API_Name__c, User_Lookup_Field_API_Name__c
             from Account_User_Rollup_Relationship_Mapping__mdt 
             where Trigger_Object_API_Name__c =: triggerObjectName];
        String accountLookupField = rollupMapping.Account_Lookup_Field_API_Name__c;
        String userLookupField = rollupMapping.User_Lookup_Field_API_Name__c;
        List<Account_User_Rollup_Field_Mapping__mdt> fieldMappings 
            = [Select Field_To_Summarize__c from Account_User_Rollup_Field_Mapping__mdt];
        List<String> fieldsToSummarize = new List<String>(Pluck.strings('Field_To_Summarize__c', fieldMappings));                                                                 
        //List<Sobject> sobjectsToConsiderForRollup = new List<Sobject>();
        Map<Id, Map<String, Double>> sobjectIdToFieldToValueToAdd2Rollup = new Map<Id, Map<String, Double>>();
        Map<Id, Id> rollupSObjToAccountId = new Map<Id, Id> ();
        Map<Id, Id> rollupSObjToUserId = new Map<Id, Id> ();
        for(Sobject newSobj: newSobjects){
            Id newSobjId = (Id)newSobj.get('Id');
            system.debug('newSobj '+newSobj);
            system.debug('accountLookupField '+accountLookupField);
            system.debug('userLookupField '+userLookupField);
            rollupSObjToAccountId.put(newSobjId, (Id)newSobj.get(accountLookupField));
            rollupSObjToUserId.put(newSobjId, (Id)newSobj.get(userLookupField));
            
            for(Account_User_Rollup_Field_Mapping__mdt fieldMapping: fieldMappings){
                String fieldToSummarize = fieldMapping.Field_To_Summarize__c;   
                Double newVal = (Double)newSobj.get(fieldToSummarize);
                Double valueToAdd = 0;
                if(Trigger.isInsert){
                    if(newVal != null){
                        valueToAdd = newVal;
                    }
                }else if(Trigger.isUpdate){
                    Sobject oldSobject = oldSobjects.get(newSobjId);
                    Double oldVal = 0;
                    if(oldSobject.get(fieldToSummarize) != null)
                        oldVal = (Double)oldSobject.get(fieldToSummarize);
                    valueToAdd = newVal- oldVal; 
                }else if(Trigger.isDelete){
                    if(newVal != null){
                        valueToAdd = 0 - newVal; 
                    }
                }
                if(!sobjectIdToFieldToValueToAdd2Rollup.containsKey(newSobjId))
                    sobjectIdToFieldToValueToAdd2Rollup.put(newSobjId, new Map<String, Double>());
                Map<String, Double> fieldToValue = sobjectIdToFieldToValueToAdd2Rollup.get(newSobjId);
                if(!fieldToValue.containsKey(fieldToSummarize))
                    fieldToValue.put(fieldToSummarize, 0);
                fieldToValue.put(fieldToSummarize, fieldToValue.get(fieldToSummarize) + valueToAdd); 
                sobjectIdToFieldToValueToAdd2Rollup.put(newSobjId, fieldToValue);
            }
        }
        system.debug('sobjectIdToFieldToValueToAdd2Rollup '+sobjectIdToFieldToValueToAdd2Rollup);
        List<Id> accIds= rollupSObjToAccountId.values();
        List<Id> userIds= rollupSObjToUserId.values();
        Map<Id, Account> idToAccs = new Map<Id, Account>(
            (List<Account>)Database.query('SELECT Id, '+ String.join(fieldsToSummarize, ',') +' from Account where id in :accIds')
        );
        Map<Id, User> idToUsers = new Map<Id, User>(
            (List<User>)Database.query('SELECT Id, '+ String.join(fieldsToSummarize, ',') +' from User where id in :userIds')
        );
        system.debug('idToAccs '+idToAccs);
        system.debug('idToUsers '+idToUsers);
        for(Id filteredSobjId: sobjectIdToFieldToValueToAdd2Rollup.keySet()){
            for(Account_User_Rollup_Field_Mapping__mdt fieldMapping: fieldMappings){
                String fieldToSummarize = fieldMapping.Field_To_Summarize__c;  
                Account relatedAcc = idToAccs.get((Id)rollupSObjToAccountId.get(filteredSobjId));
                User relatedUser = idToUsers.get((Id)rollupSObjToUserId.get(filteredSobjId));
                Double accNewVal = sobjectIdToFieldToValueToAdd2Rollup.get(filteredSobjId).get(fieldToSummarize);
                system.debug('relatedAcc '+relatedAcc);
                system.debug('relatedUser '+relatedUser);
                system.debug('accNewVal '+accNewVal);
                if(relatedAcc.get(fieldToSummarize) != null)
                    accNewVal += (Double)relatedAcc.get(fieldToSummarize);
                Double userNewVal = sobjectIdToFieldToValueToAdd2Rollup.get(filteredSobjId).get(fieldToSummarize);
                if(relatedUser.get(fieldToSummarize) != null)
                    userNewVal += (Double)relatedUser.get(fieldToSummarize);
                relatedAcc.put(fieldToSummarize, accNewVal);
                idToAccs.put(relatedAcc.Id, relatedAcc);
                relatedUser.put(fieldToSummarize, userNewVal);
                idToUsers.put(relatedUser.Id, relatedUser);
            }
        }
        update idToAccs.values();
        update idToUsers.values();
    }*/
}