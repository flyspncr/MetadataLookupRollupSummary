trigger AccountTrigger on Account (after insert, after update, after delete, after undelete) {
    Account[] objects = null;  
    if(Trigger.isInsert){
        objects = Trigger.new;        
    }
    else if(Trigger.isUpdate){
        objects = RollupServices.filterUpdatedRollupFieldRecords(Trigger.new, Trigger.oldMap, 'Account');        
    }    
    else if(Trigger.isDelete){
        objects = Trigger.old;
    }    
    else if(Trigger.isunDelete){
        objects = Trigger.new;
    }
    RollupServices.doRollup(objects, 'Account');
}