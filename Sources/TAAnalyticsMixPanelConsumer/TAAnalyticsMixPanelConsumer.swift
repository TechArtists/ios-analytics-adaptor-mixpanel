/*
MIT License

Copyright (c) 2025 Tech Artists Agency

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

//  TAAppsFlyerConsumer.swift
//  Created by Adi on 10/24/22.
//
//  Copyright (c) 2022 TA SRL (http://TA.com/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import Foundation
import OSLog
import TAAnalytics
import Mixpanel

public class MixPanelConsumer: AnalyticsConsumer {
   
    public typealias T = MixPanelConsumer
    
    public var wrappedValue: Self {
        self
    }
    
    let mixPanelInstance: MixpanelInstance = Mixpanel.mainInstance()
    
    let mixPanelToken: String

    init(mixpanelToken: String) {
        self.mixPanelToken = mixpanelToken
    }
    
    public func startFor(installType: TAAnalyticsConfig.InstallType, userDefaults: UserDefaults, TAAnalytics: TAAnalytics) async throws {
        Mixpanel.initialize(token: mixPanelToken, trackAutomaticEvents: false)
    }

    public func track(trimmedEvent: TrimmedEvent, params: [String: AnalyticsBaseParameterValue]?) {
        let event = trimmedEvent.event
        
        let validParams = validEventParams(forEvent: event, params: params)
        
        mixPanelInstance.track(event: event.rawValue, properties: validParams)
    }
    
    private func validEventParams(forEvent event: AnalyticsEvent, params: [String: AnalyticsBaseParameterValue]?) -> [String: MixpanelType]? {
        guard let params = params else { return nil }
        
        var newParams = [String: MixpanelType]()
        
        for (key, value) in params {
            if key.count > 40 || ((value as? String)?.count ?? 0) > 100 {
                let newKey = String(key.prefix(40))
                var newValue = value
                var newValueString = ""
                if let value = value as? String {
                    newValue = String(value.prefix(100))
                    newValueString = String(value.prefix(100))
                }
                
                newParams[newKey] = convert(parameter: newValue)
                
                os_log(
                    "Will trim parameters for event '%{public}@', key: '%{public}@', value: '%@'",
                    log: TAAnalytics.logger,
                    type: .error,
                    event.rawValue,
                    newKey,
                    newValueString
                )
            } else {
                newParams[key] = convert(parameter: value)
            }
        }
        return newParams
    }
    
    private func convert(parameter: AnalyticsBaseParameterValue) -> MixpanelType {
        guard let parameter = parameter as? MixpanelType else {
            fatalError("Unsupported base parameter type \(parameter)")
        }
        return parameter
    }

    public func set(trimmedUserProperty: TrimmedUserProperty, to value: String?) {
        let userProperty = trimmedUserProperty.userProperty
        
    }

    public func trim(event: AnalyticsEvent) -> TrimmedEvent {
        TrimmedEvent(event.rawValue.ob_trim(type: "event", toLength: 40))
    }

    public func trim(userProperty: AnalyticsUserProperty) -> TrimmedUserProperty {
        TrimmedUserProperty(userProperty.rawValue.ob_trim(type: "user property", toLength: 24))
    }
}
