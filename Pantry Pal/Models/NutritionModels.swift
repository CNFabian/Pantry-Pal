//
//  NutritionModels.swift
//  Pantry Pal
//

import Foundation

struct NutritionInfo: Codable {
    let calories: Double?
    let carbohydrate: Double?
    let protein: Double?
    let fat: Double?
    let saturatedFat: Double?
    let polyunsaturatedFat: Double?
    let monounsaturatedFat: Double?
    let cholesterol: Double?
    let sodium: Double?
    let potassium: Double?
    let fiber: Double?
    let sugar: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let calcium: Double?
    let iron: Double?
    
    init(from serving: FatSecretServing) {
        self.calories = Double(serving.calories)
        self.carbohydrate = Double(serving.carbohydrate ?? "0")
        self.protein = Double(serving.protein ?? "0")
        self.fat = Double(serving.fat ?? "0")
        self.saturatedFat = Double(serving.saturated_fat ?? "0")
        self.polyunsaturatedFat = Double(serving.polyunsaturated_fat ?? "0")
        self.monounsaturatedFat = Double(serving.monounsaturated_fat ?? "0")
        self.cholesterol = Double(serving.cholesterol ?? "0")
        self.sodium = Double(serving.sodium ?? "0")
        self.potassium = Double(serving.potassium ?? "0")
        self.fiber = Double(serving.fiber ?? "0")
        self.sugar = Double(serving.sugar ?? "0")
        self.vitaminA = Double(serving.vitamin_a ?? "0")
        self.vitaminC = Double(serving.vitamin_c ?? "0")
        self.calcium = Double(serving.calcium ?? "0")
        self.iron = Double(serving.iron ?? "0")
    }
}

struct ServingInfo: Codable {
    let servingId: String
    let servingDescription: String
    let metricServingAmount: Double?
    let metricServingUnit: String?
    let numberOfUnits: Double?
    let measurementDescription: String
    
    init(from serving: FatSecretServing) {
        self.servingId = serving.serving_id
        self.servingDescription = serving.serving_description
        self.metricServingAmount = Double(serving.metric_serving_amount ?? "0")
        self.metricServingUnit = serving.metric_serving_unit
        self.numberOfUnits = Double(serving.number_of_units ?? "0")
        self.measurementDescription = serving.measurement_description
    }
}
