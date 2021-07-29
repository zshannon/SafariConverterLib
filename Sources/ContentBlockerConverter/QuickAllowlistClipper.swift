import Foundation

protocol QuickAllowlistClipperProtocol {
    func convertRuleToJsonString(ruleText: String) throws -> String
    func add(rule: String, to conversionResult: ConversionResult) throws -> ConversionResult
    func remove(rule: String, from conversionResult: ConversionResult) throws -> ConversionResult
    func replace(rule: String, with newRule: String, in conversionResult: ConversionResult) throws -> ConversionResult
    func addAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult
    func addInvertedAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult
    func removeAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult
    func removeInvertedAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult
}

/**
 * Special service for managing allowlist rules:
 * quickly add/remove allowlist rules without filters recompilation
 */
public class QuickAllowlistClipper: QuickAllowlistClipperProtocol {
    let converter = ContentBlockerConverter();

    /**
     * Converts provided rule to json format and returns as string
     */
    func convertRuleToJsonString(ruleText: String) throws -> String {
        guard let conversionResult = converter.convertArray(rules: [ruleText]) else {
            throw QuickAllowlistClipperError.errorConvertingRule;
        }
        let convertedRule = conversionResult.converted.dropFirst(1).dropLast(1);
        return String(convertedRule);
    }
    
    /**
     * Appends provided rule to conversion result
     */
    public func add(rule: String, to conversionResult: ConversionResult) throws -> ConversionResult {
        let convertedRule = try convertRuleToJsonString(ruleText: rule);
        
        var result = conversionResult;
        result.converted = String(result.converted.dropLast(1));
        result.converted += ",\(convertedRule)]"
        result.convertedCount += 1;
        result.totalConvertedCount += 1;
        
        return result;
    }
    
    /**
     * Removes provided rule from conversion result
     */
    public func remove(rule: String, from conversionResult: ConversionResult) throws -> ConversionResult {
        let convertedRule = try convertRuleToJsonString(ruleText: rule);
        
        if !conversionResult.converted.contains(convertedRule) {
            throw QuickAllowlistClipperError.errorRemovingRule;
        }
        
        var result = conversionResult;
        result.converted = result.converted.replace(target: convertedRule, withString: "");
        
        // remove redundant commas
        if result.converted.hasPrefix("[,{") {
            result.converted = result.converted.replace(target: "[,{", withString: "[{");
        } else if result.converted.hasSuffix("},]") {
            result.converted = result.converted.replace(target: "},]", withString: "}]");
        } else if result.converted.contains(",,") {
            result.converted = result.converted.replace(target: ",,", withString: ",");
        }
        // handle empty result
        if result.converted == "[]" {
            return try ConversionResult.createEmptyResult();
        }
        
        result.convertedCount -= 1;
        result.totalConvertedCount -= 1;
        
        return result;
    }
    
    /**
     * Replaces rule in conversion result with provided rule
     */
    public func replace(rule: String, with newRule: String, in conversionResult: ConversionResult) throws -> ConversionResult {
        var result = try remove(rule: rule, from: conversionResult);
        result = try add(rule: newRule, to: result);
        return result;
    }
    
    /**
     * Creates allowlist rule for provided domain
     */
    func createAllowlistRule(by domain: String) -> String {
        return "@@||\(domain)$document";
    }
    
    /**
     * Creates inverted allowlist rule for provided domain
     */
    func createInvertedAllowlistRule(by domain: String) -> String {
        return "@@||*$document,domain=~\(domain)";
    }
    
    /**
     * Appends allowlist rule for provided domain to conversion result
     */
    public func addAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult {
        let allowlistRule = createAllowlistRule(by: domain);
        return try add(rule: allowlistRule, to: conversionResult);
    }
    
    /**
     * Appends inverted allowlist rule for provided domain to conversion result
     */
    public func addInvertedAllowlistRule(by domain: String, to conversionResult: ConversionResult) throws -> ConversionResult {
        let invertedAllowlistRule = createInvertedAllowlistRule(by: domain);
        return try add(rule: invertedAllowlistRule, to: conversionResult);
    }
    
    /**
     * Removes allowlist rule for provided domain from conversion result
     */
    public func removeAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult {
        let allowlistRule = createAllowlistRule(by: domain);
        return try remove(rule: allowlistRule, from: conversionResult);
    }
    
    /**
     * Removes inverted allowlist rule for provided domain from conversion result
     */
    public func removeInvertedAllowlistRule(by domain: String, from conversionResult: ConversionResult) throws -> ConversionResult {
        let invertedAllowlistRule = createInvertedAllowlistRule(by: domain);
        return try remove(rule: invertedAllowlistRule, from: conversionResult);
    }
}

public enum QuickAllowlistClipperError: Error, CustomDebugStringConvertible {
    case errorConvertingRule
    case errorRemovingRule
    
    public var debugDescription: String {
        switch self {
            case .errorConvertingRule: return "A rule conversion error has occurred"
            case .errorRemovingRule: return "Conversion result doesn't contain provided rule"
        }
    }
}
