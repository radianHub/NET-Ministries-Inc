public class MatchExistingLeadQueueable implements Queueable {
	private List<Lead> leads;

	public MatchExistingLeadQueueable(List<Lead> leads) {
		this.leads = leads;
	}

	public void execute(System.QueueableContext qc) {
		Set<String> uniqueFields = new Set<String>();
		Schema.FieldSet initialFormFielset = SObjectType.Lead.FieldSets.getMap().get('Initial_Form_Fields');
		Schema.FieldSet fullFormFieldset = SObjectType.Lead.FieldSets.getMap().get('Full_Form_Fields');

		for (Schema.FieldSetMember field : initialFormFielset.getFields()) {
			uniqueFields.add(field.getFieldPath());
		}
		for (Schema.FieldSetMember field : fullFormFieldset.getFields()) {
			uniqueFields.add(field.getFieldPath());
		}

		List<Lead> leadsToDelete = new List<Lead>();
		List<Lead> leadsToUpdate = new List<Lead>();

		Set<String> filterFields = Pluck.strings('Formstack_Filter__c', leads);
		Set<Id> leadIds = Pluck.ids(leads);

		String initialQuery = 'SELECT Id, Status, {0} FROM Lead WHERE Formstack_Filter__c IN :filterFields AND Id NOT IN :leadIds';
		String query = String.format(initialQuery, new List<String>{ String.join(uniqueFields, ', ') });
		List<Lead> existingLeads = Database.query(query);

		Map<String, Lead> filterLeadMap = new Map<String, Lead>();

		Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();

		for (Lead lead : existingLeads) {
			filterLeadMap.put(lead.Formstack_Filter__c, lead);
		}

		for (Lead lead : leads) {
			Lead existingLead = filterLeadMap.get(lead.Formstack_Filter__c);

			if (existingLead == null) {
				continue;
			}

			if (lead.Initial_Form_ID__c.contains('Interest Application Id')) {
				if (existingLead.Status == 'Prospecting') {
					for (Schema.FieldSetMember fieldMember : initialFormFielset.getFields()) {
						String field = fieldMember.getFieldPath();

						if (field == 'Initial_Form_ID__c') {
							existingLead.put(field, existingLead.get(field) + '\n ' + lead.get(field));
						} else if (leadFieldMap.get(field).getDescribe().isUpdateable()) {
							existingLead.put(field, lead.get(field));
						}
					}
				}
			} else if (lead.Initial_Form_ID__c.contains('Full Form Id')) {
				if (existingLead.Status == 'Prospecting' || existingLead.Status == 'Application Requested') {
					for (Schema.FieldSetMember fieldMember : fullFormFieldset.getFields()) {
						String field = fieldMember.getFieldPath();

						if (field == 'Initial_Form_ID__c') {
							existingLead.put(field, existingLead.get(field) + '\n ' + lead.get(field));
						} else if (leadFieldMap.get(field).getDescribe().isUpdateable()) {
							existingLead.put(field, lead.get(field));
						}
					}
					existingLead.put('Status', 'Application Submitted');
				}
			}

			leadsToUpdate.add(existingLead);
			leadsToDelete.add(lead);
		}

		if (leadsToUpdate.size() > 0) {
			update leadsToUpdate;
		}

		if (leadsToDelete.size() > 0) {
			delete leadsToDelete;
		}
	}
}