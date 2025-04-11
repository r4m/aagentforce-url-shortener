public without sharing class ShortUrlRedirectController {
    @AuraEnabled(cacheable=true)
    public static String findLongUrl(String shortCode) {
        List<Shortened_URL__c> urls = [
            SELECT Long_URL__c
            FROM Shortened_URL__c
            WHERE Short_Code__c = :shortCode
            LIMIT 1
        ];

        if (!urls.isEmpty()) {
            return urls[0].Long_URL__c;
        } else {
            throw new AuraHandledException('Short URL not found.');
        }
    }
}