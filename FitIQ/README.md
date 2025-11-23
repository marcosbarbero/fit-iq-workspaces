# FitIQ - Fitness Intelligence Quotient

A comprehensive health and fitness tracking application built with Swift 6 and iOS 26, following Hexagonal Architecture principles.

## Folder Structure

```
📦 YourAppRoot
 ├── 🍎 Presentation (UI / Primary Adapters)
 │   ├── UI (SwiftUI Views)
 │   │   ├── NutritionView
 │   │   ├── AddMealView
 │   │   ├── Components (MealTypeButton, QuickLogTilesView, etc.)
 │   │   └── Sheets (MealPlanQuickSelectView, ImageMealReviewView)
 │   │
 │   └── ViewModels (UI Adapters)
 │       ├── NutritionViewModel (@Observable)
 │       └── AddMealViewModel (@Observable)
 │
 ├── 🟢 Domain (Core / The Hexagon)
 │   ├── Entities (Core Data Models)
 │   │   ├── Meal.swift        (@Model Entity)
 │   │   ├── MealItem.swift    (@Model Entity)
 │   │   └── Enums (MealType, MealState)
 │   │
 │   ├── UseCases (Primary Ports / Business Logic)
 │   │   ├── AddMealUseCase.swift (Protocol)
 │   │   └── CreateMealUseCase.swift (Implementation)
 │   │   └── MealUpdateUseCase.swift (Protocol for background result)
 │   │   └── LocalMealUpdateUseCase.swift (Implementation)
 │   │
 │   ├── Ports (Secondary Output Ports)
 │   │   ├── MealRepositoryProtocol.swift        // Interface for local storage
 │   │   └── MealParsingAPIServiceProtocol.swift // Interface for external API
 │   │
 │   └── Events (Inter-Service Communication)
 │       ├── NutritionEvent.swift
 │       └── NutritionEventPublisher.swift
 │
 └── 🛠️ Infrastructure (Secondary Adapters)
     ├── Persistence (Local Storage Adapters)
     │   └── SwiftDataMealRepository.swift (Implements MealRepositoryProtocol)
     │
     ├── Network (API Adapters)
     │   ├── DTOs (CreateMealRequestDTO, MealResponseDTO, etc.)
     │   └── MealParsingAPIClient.swift (Implements MealParsingAPIServiceProtocol)
     │
     ├── Services (Background & Utility Adapters)
     │   ├── MealParsingBackgroundService.swift (The Event Listener/Orchestrator)
     │   └── SpeechRecognizer.swift
     │
     └── Configuration (Dependency Injection)
         └── AppContainer.swift (Sets up all dependencies for runtime
```
