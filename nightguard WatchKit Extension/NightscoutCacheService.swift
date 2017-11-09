//
//  NightscoutCacheService.swift
//  nightguard WatchKit Extension
//
//  Created by Dirk Hermanns on 06.11.17.
//  Copyright © 2017 private. All rights reserved.
//

import Foundation

// This is a facade in front of the nightscout service. It is used to reduce the
// amount of turnarounds to the real backend to a minimum
class NightscoutCacheService {
    
    static let singleton = NightscoutCacheService()
    
    fileprivate var todaysBgData : [BloodSugar]? = nil
    fileprivate var yesterdaysBgData : [BloodSugar]? = nil
    fileprivate var yesterdaysDayOfTheYear : Int? = nil
    fileprivate var currentNightscoutData : NightscoutData? = nil
    
    fileprivate let ONE_DAY_IN_MICROSECONDS = Double(60*60*24*1000)
    
    func resetCache() {
        todaysBgData = nil
        yesterdaysBgData = nil
        yesterdaysDayOfTheYear = nil
        currentNightscoutData = nil
    }
    
    func loadCurrentNightscoutData(_ resultHandler : @escaping ((NightscoutData) -> Void))
        -> NightscoutData {
        
        if currentNightscoutData == nil {
            currentNightscoutData = NightscoutDataRepository.singleton.loadCurrentNightscoutData()
        }
        
        checkIfRefreshIsNeeded(resultHandler)
        
        return currentNightscoutData!
    }
    
    // Reads the blood glucose data from today
    func loadTodaysData(_ resultHandler : @escaping (([BloodSugar]) -> Void))
        -> [BloodSugar] {
        
        if todaysBgData == nil {
           todaysBgData = NightscoutDataRepository.singleton.loadTodaysBgData()
        }
        
        if todaysBgData!.count == 0 || currentNightscoutData == nil || currentNightscoutData!.isOlderThan5Minutes() {
            
            NightscoutService.singleton.readTodaysChartData({(todaysBgData) -> Void in
                
                self.todaysBgData = todaysBgData
                resultHandler(todaysBgData)
            })
        }
        return todaysBgData!
    }
    
    // Reads the blood glucose data from yesterday
    func loadYesterdaysData(_ resultHandler : @escaping (([BloodSugar]) -> Void))
        -> [BloodSugar] {
        
        if yesterdaysBgData == nil {
            yesterdaysBgData = NightscoutDataRepository.singleton.loadYesterdaysBgData()
            yesterdaysDayOfTheYear = NightscoutDataRepository.singleton.loadYesterdaysDayOfTheYear()
        }
        
        if yesterdaysBgData!.count == 0 || currentNightscoutData == nil || yesterdaysValuesAreOutdated() {
            
            NightscoutService.singleton.readYesterdaysChartData({(yesterdaysValues) -> Void in
                
                // transform the yesterdays values to the current day, so that they can be easily displayed in
                // one diagram
                self.yesterdaysBgData = self.transformToCurrentDay(yesterdaysValues: yesterdaysValues)
                NightscoutDataRepository.singleton.storeYesterdaysBgData(self.yesterdaysBgData!)
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                self.yesterdaysDayOfTheYear = Calendar.current.ordinality(of: .day, in: .year, for: yesterday)!
                NightscoutDataRepository.singleton.storeYesterdaysDayOfTheYear(yesterdaysDayOfTheYear: self.yesterdaysDayOfTheYear!)
                
                resultHandler(self.yesterdaysBgData!)
            })
        }
        return yesterdaysBgData!
    }
    
    // check if the stored yesterdaysvalues are from a day before
    fileprivate func yesterdaysValuesAreOutdated() -> Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let newYesterdayDayOfTheYear = Calendar.current.ordinality(of: .day, in: .year, for: yesterday)!
        
        return newYesterdayDayOfTheYear != yesterdaysDayOfTheYear
    }
    
    fileprivate func transformToCurrentDay(yesterdaysValues : [BloodSugar]) -> [BloodSugar] {
        var transformedValues : [BloodSugar] = []
        for yesterdaysValue in yesterdaysValues {
            let transformedValue = BloodSugar.init(value: yesterdaysValue.value, timestamp: yesterdaysValue.timestamp + self.ONE_DAY_IN_MICROSECONDS)
            transformedValues.append(transformedValue)
        }
        
        return transformedValues
    }
    
    fileprivate func checkIfRefreshIsNeeded(_ resultHandler : @escaping ((NightscoutData) -> Void)) {
        
        if currentNightscoutData!.isOlderThan5Minutes() {
            NightscoutService.singleton.readCurrentDataForPebbleWatch({ (newNightscoutData) in
                
                self.currentNightscoutData = newNightscoutData
                NightscoutDataRepository.singleton.storeCurrentNightscoutData(self.currentNightscoutData!)
                
                resultHandler(newNightscoutData)
            })
        }
    }
}