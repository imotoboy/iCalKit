//
//  CKCalendar+Extensions.swift
//  iCalendarKit
//
//  Created by tramp on 2021/3/4.
//

import Foundation
import EventKit

extension CKCalendar {
    
    
    /// get EKEvent form calender
    /// - Parameter store: EKEventStore
    /// - Throws: Error
    /// - Returns: [EKEvent]
    public func events(with store: EKEventStore) throws -> [EKEvent] {
        return try events.map {
            return try convert(evt: $0, with: store)
        }
    }
  
    /// convert CKEvent to EK Event
    /// - Parameters:
    ///   - evt: CKEvent
    ///   - store: EKEventStore
    /// - Throws: Error
    /// - Returns: EKEvent
    private func convert(evt: CKEvent, with store: EKEventStore) throws -> EKEvent {
        guard evt.openUID.isEmpty == false else { throw CKError.custom("Can not get open UID from CKEvent") }
        let startDate = try self.beginTime(for: evt)
        let predicate = store.predicateForEvents(withStart: startDate, end: startDate.addingTimeInterval(0.1), calendars: nil)
        let event: EKEvent
        if let _event = store.events(matching: predicate).first(where: { $0.hasNotes == true && $0.notes?.contains(evt.openUID) == true }) {
            event = _event
        } else {
            event = EKEvent.init(eventStore: store)
        }
        // 设置标题
        if let title = evt.component(for: .SUMMARY)?.value.replacingOccurrences(of: "\\r\\n", with: "") {
            event.title = title
        }
        // 设置 notes
        if let notes = evt.component(for: .DESCRIPTION)?.value.replacingOccurrences(of: "\\r\\n", with: ""), notes.isEmpty == false {
            event.notes = evt.openUID + "\n" + notes
        } else {
            event.notes = evt.openUID
        }
        // 设置位置信息
        if let location = evt.component(for: .LOCATION)?.value.replacingOccurrences(of: "\\r\\n", with: "") {
            event.location = location
        }
        // 设置URL
        if let link = evt.component(for: .URL)?.value, let url = URL.init(string: link) {
            event.url = url
        }
        // 设置开始时间
        event.startDate = startDate
        // 设置结束时间
        if let attr = evt.component(for: .DTEND) {
            event.endDate = date(from: attr)
        }
        // GEO
        if #available(macOS 10.11, iOS 6.0, watchOS 2.0, *), let attr = evt.component(for: .GEO) {
            event.structuredLocation?.geoLocation = geo(from: attr)
        }
        
        /// EKCalendar
        event.calendar = store.defaultCalendarForNewEvents
        
        return event
    }
}

extension CKCalendar {
    
    /// date from CKComponent
    /// - Parameter component: CKComponent
    /// - Returns: Date
    public func date(from component: CKComponent) -> Date? {
        let contents = component.value.replacingOccurrences(of: "T", with: "", options: [.caseInsensitive], range: nil)
        let dateFormatter: DateFormatter = .init()
        let formats: [String] = [
            "yyyyMMddHHmmss",
            "yyyyMMddHHmm",
            "yyyyMMddHH",
            "yyyyMMdd"
        ]
        if contents.hub.hasSuffix(["Z","z"]) == true {
            let formats = formats.map { $0 + "Z" }
            return dateFormatter.hub.date(from: contents, supports: formats)
        } else if let TZID = component.value(for: "TZID") {
            dateFormatter.timeZone = TZID.hub.toTimeZone()
            return dateFormatter.hub.date(from: contents, supports: formats)
        } else if timezones.isEmpty == false, let TZID = timezones.first?.component(for: .TZID)?.value  {
            dateFormatter.timeZone = TZID.hub.toTimeZone()
            return dateFormatter.hub.date(from: contents, supports: formats)
        } else {
            dateFormatter.timeZone = "Asia/Shanghai".hub.toTimeZone()
            return dateFormatter.hub.date(from: contents, supports: formats)
        }
    }
    
    /// geo from CKComponent
    /// - Parameter component: CKComponent
    /// - Returns: CLLocation?
    public func geo(from component: CKComponent) -> CLLocation? {
        guard component.value.contains(";") == true else { return nil }
        let components = component.value.components(separatedBy: ";")
        let latitude: CLLocationDegrees = components[0].hub.doubleValue
        let longitude: CLLocationDegrees = components[1].hub.doubleValue
        return .init(latitude: latitude, longitude: longitude)
    }
    
    /// begin date for CKEvent
    /// - Parameter event: CKEvent
    /// - Throws: Error
    /// - Returns: Date
    public func beginTime(for event: CKEvent) throws -> Date {
        if let attr = event.component(for: .DTSTART), let date = date(from: attr) {
            return date
        } else if let attr = event.component(for: .DTSTAMP), let date = date(from: attr) {
            return date
        } else {
            throw CKError.custom("Can not get start date for CKEvent")
        }
    }
    
    /// end time for CKEvent
    /// - Parameter event: CKEvent
    /// - Throws: Error
    /// - Returns: Date
    public func endTime(for event: CKEvent) throws -> Date {
        if let attr = event.component(for: .DTEND), let date = date(from: attr) {
            return date
        } else {
            throw CKError.custom("Can not get end date for CKEvent")
        }
        
    }
}
