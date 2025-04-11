public class ShortURLFlowHelper {
    @InvocableMethod(label='Genera codice breve per URL')
    public static List<Output> generateShortCode(List<Input> inputs) {
        List<Output> results = new List<Output>();

        if (inputs != null && !inputs.isEmpty()) {
            String longUrl = inputs[0].longUrl;
            String code = EncodingUtil.convertToHex(
                Crypto.generateDigest('MD5', Blob.valueOf(longUrl))
            ).substring(0, 6);

            Output o = new Output();
            o.shortCode = code;
            results.add(o);
        }

        return results;
    }

    public class Input {
        @InvocableVariable(label='URL lungo')
        public String longUrl;
    }

    public class Output {
        @InvocableVariable(label='Codice breve generato')
        public String shortCode;
    }
}