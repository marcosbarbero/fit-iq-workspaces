import Foundation
import SwiftUI

// MARK: - Localization Keys

/// Helper function to get localized string from LocaleManager's bundle
/// This ensures that runtime language changes are reflected immediately
private func localized(_ key: String) -> String {
    return LocaleManager.shared.localizedString(forKey: key)
}

/// Centralized localization keys using enums for type safety
/// This prevents typos and provides autocomplete support
struct L10n {

    // MARK: - Login
    enum Login {
        static var title: String { localized("login.title") }
        static var subtitle: String { localized("login.subtitle") }
        static var email: String { localized("login.email") }
        static var password: String { localized("login.password") }
        static var forgotPassword: String { localized("login.forgot_password") }
        static var signIn: String { localized("login.sign_in") }
        static var signInProgress: String { localized("login.sign_in_progress") }
        static var or: String { localized("login.or") }

    }

    // MARK: - Registration
    enum Registration {
        static var title: String { localized("registration.title") }
        static var subtitle: String { localized("registration.subtitle") }
        static var email: String { localized("registration.email") }
        static var username: String { localized("registration.username") }
        static var password: String { localized("registration.password") }
        static var name: String { localized("registration.name") }
        static var dateOfBirth: String { localized("registration.date_of_birth") }
        static var createAccount: String { localized("registration.create_account") }
        static var or: String { localized("registration.or") }
        static var registerProgress: String { localized("registration.register_progress") }
    }

    // MARK: - Landing Page
    enum LandingPage {
        static var welcome: String { localized("landing.welcome") }
        static var subtitle: String { localized("landing.tagline") }
        static var signIn: String { localized("landing.sign_in") }
        static var signUp: String { localized("landing.sign_up") }
        static var trackingWorkout: String { localized("landing.tracking_workout") }
        static var trackingNutrition: String { localized("landing.tracking_nutrition") }
        static var trackingSleep: String { localized("landing.tracking_sleep") }
        static var trackingGoals: String { localized("landing.tracking_goals") }
        static var trackingMood: String { localized("landing.tracking_mood") }
    }

    // MARK: - Common Actions
    enum Common {
        static var save: String { localized("common.save") }
        static var cancel: String { localized("common.cancel") }
        static var delete: String { localized("common.delete") }
        static var done: String { localized("common.done") }
        static var edit: String { localized("common.edit") }
        static var add: String { localized("common.add") }
        static var ok: String { localized("common.ok") }
        static var skip: String { localized("common.skip") }
        static var clear: String { localized("common.clear") }
        static var retry: String { localized("common.retry") }
        static var logout: String { localized("common.logout") }
        static var `continue`: String { localized("common.continue") }
        static var ssoGoogle: String { localized("common.sso_google") }
        static var ssoApple: String { localized("common.sso_apple") }
    }

    // MARK: - Navigation
    enum Navigation {
        static var summary: String { localized("navigation.summary") }
        static var workouts: String { localized("navigation.workouts") }
        static var nutrition: String { localized("navigation.nutrition") }
        static var plan: String { localized("navigation.plan") }
        static var coach: String { localized("navigation.coach") }
        static var goals: String { localized("navigation.goals") }
        static var sleep: String { localized("navigation.sleep") }
        static var profile: String { localized("navigation.profile") }
        static var community: String { localized("navigation.community") }

        enum Title {
            static var dailyGoals: String { localized("navigation.title.daily_goals") }
            static var longTermGoals: String { localized("navigation.title.long_term_goals") }
            static var newGoal: String { localized("navigation.title.new_goal") }
            static var goalDetails: String { localized("navigation.title.goal_details") }
            static var editProfile: String { localized("navigation.title.edit_profile") }
            static var myProfile: String { localized("navigation.title.my_profile") }
            static var measurements: String { localized("navigation.title.measurements") }
            static var mealPlans: String { localized("navigation.title.meal_plans") }
            static var createMealPlan: String { localized("navigation.title.create_meal_plan") }
            static var editMealPlan: String { localized("navigation.title.edit_meal_plan") }  // ADDED
            static var editMeal: String { localized("navigation.title.edit_meal") }
            static var editMealGroup: String { localized("navigation.title.edit_meal_group") }
            static var morningCheckin: String { localized("navigation.title.morning_checkin") }
            static var logMood: String { localized("navigation.title.log_mood") }
            static var myPlanToday: String { localized("navigation.title.my_plan_today") }
            static var customizeSummary: String { localized("navigation.title.customize_summary") }
            static var feed: String { localized("navigation.title.feed") }
            static var foodDrink: String { localized("navigation.title.food_drink") }
            static var newLongTermGoal: String { localized("navigation.title.new_long_term_goal") }
            static var bodyMass: String { localized("navigation.title.body_mass") }  // ADDED
        }
    }

    // MARK: - Goals
    enum Goals {
        static var daily: String { localized("goals.daily") }
        static var longTerm: String { localized("goals.long_term") }
        static var active: String { localized("goals.active") }
        static var activeLabel: String { localized("goals.active_label") }
        static var activeGoals: String { localized("goals.active_goals") }
        static var completed: String { localized("goals.completed") }
        static var addGoal: String { localized("goals.add_goal") }
        static var confidence: String { localized("goals.confidence") }
        static var dailyProgress: String { localized("goals.daily_progress") }
        static var aiAdviceDaily: String { localized("goals.ai_advice_daily") }
        static var water: String { localized("goals.water") }
        static var steps: String { localized("goals.steps") }
        static var activityHydration: String { localized("goals.activity_hydration") }
        static var clearGoals: String { localized("goals.clear_goals") }
        static var target: String { localized("goals.target") }

        static func completedOn(_ date: String) -> String {
            String(format: localized("goals.completed_on"), date)
        }

        static func goalCount(_ count: Int) -> String {
            String(format: localized("goals.goal_count"), count)
        }

        static func activeGoalCount(_ count: Int) -> String {
            String(format: localized("goals.active_goal_count"), count)
        }

        enum Status {
            static var active: String { localized("goals.status.active") }
            static var complete: String { localized("goals.status.complete") }
            static var completed: String { localized("goals.status.completed") }
        }
    }

    // MARK: - Plan (My Plan Today)
    enum Plan {
        static var myPlanToday: String { localized("plan.my_plan_today") }
        static var todaysProgress: String { localized("plan.todays_progress") }
        static var workout: String { localized("plan.workout") }
        static var nutrition: String { localized("plan.nutrition") }
        static var todaysGoals: String { localized("plan.todays_goals") }
        static var markComplete: String { localized("plan.mark_complete") }
        static var complete: String { localized("plan.complete") }
        static var swapMeal: String { localized("plan.swap_meal") }
        static var noPlanToday: String { localized("plan.no_plan_today") }
        static var generatePersonalized: String { localized("plan.generate_personalized") }
        static var generatePlan: String { localized("plan.generate_plan") }
        static var generateYourPlan: String { localized("plan.generate_your_plan") }
        static var aiWillCreate: String { localized("plan.ai_will_create") }
        static var activeGoals: String { localized("plan.active_goals") }

        static func swapFormat(_ mealType: String) -> String {
            String(format: localized("plan.swap_format"), mealType)
        }

        static func setsRepsFormat(_ sets: Int, _ reps: Int) -> String {
            String(format: localized("plan.sets_reps_format"), sets, reps)
        }

        static func targetKcalFormat(_ kcal: Int) -> String {
            String(format: localized("plan.target_kcal_format"), kcal)
        }
    }

    // MARK: - Nutrition
    enum Nutrition {
        static var addMeal: String { localized("nutrition.add_meal") }
        static var editMeal: String { localized("nutrition.edit_meal") }
        static var deleteMeal: String { localized("nutrition.delete_meal") }
        static var logMeal: String { localized("nutrition.log_meal") }
        static var addWater: String { localized("nutrition.add_water") }
        static var meal: String { localized("nutrition.meal") }
        static var calories: String { localized("nutrition.calories") }
        static var protein: String { localized("nutrition.protein") }
        static var carbs: String { localized("nutrition.carbs") }
        static var fat: String { localized("nutrition.fat") }
        static var proteinAbbr: String { localized("nutrition.protein_abbr") }
        static var carbsAbbr: String { localized("nutrition.carbs_abbr") }
        static var fatAbbr: String { localized("nutrition.fat_abbr") }
        static var caloriesKcal: String { localized("nutrition.calories_kcal") }
        static var proteinG: String { localized("nutrition.protein_g") }
        static var carbsG: String { localized("nutrition.carbs_g") }
        static var fatG: String { localized("nutrition.fat_g") }
        static var caloriesBurned: String { localized("nutrition.calories_burned") }
        static var caloricDeficit: String { localized("nutrition.caloric_deficit") }
        static var currentDeficit: String { localized("nutrition.current_deficit") }
        static var basal: String { localized("nutrition.basal") }
        static var quickAddFromPlans: String { localized("nutrition.quick_add_from_plans") }
        static var snapPhoto: String { localized("nutrition.snap_photo") }
        static var enterFoodDescription: String { localized("nutrition.enter_food_description") }
        static var choosePhotoSource: String { localized("nutrition.choose_photo_source") }
        static var takePhoto: String { localized("nutrition.take_photo") }
        static var chooseFromLibrary: String { localized("nutrition.choose_from_library") }
        static var filterByMealType: String { localized("nutrition.filter_by_meal_type") }
        static var createMealPlanPrompt: String { localized("nutrition.create_meal_plan_prompt") }
        static var quickAddMealPlan: String { localized("nutrition.quick_add_meal_plan") }
        static var foodAndDrink: String { localized("nutrition.food_and_drink") }

        static func kcalLogged(_ kcal: Int) -> String {
            String(format: localized("nutrition.kcal_logged"), kcal)
        }

        static func kcalValue(_ kcal: Int) -> String {
            String(format: localized("nutrition.kcal_value"), kcal)
        }

        static func noMealPlansFor(_ mealType: String) -> String {
            String(format: localized("nutrition.no_meal_plans_for"), mealType)
        }

        enum MealType {
            static var breakfast: String { localized("nutrition.meal_type.breakfast") }
            static var lunch: String { localized("nutrition.meal_type.lunch") }
            static var dinner: String { localized("nutrition.meal_type.dinner") }
            static var snack: String { localized("nutrition.meal_type.snack") }
            static var drink: String { localized("nutrition.meal_type.drink") }
            static var water: String { localized("nutrition.meal_type.water") }
            static var supplements: String { localized("nutrition.meal_type.supplements") }
            static var other: String { localized("nutrition.meal_type.other") }
        }

        static var mealPlans: String { localized("nutrition.meal_plans") }
        static var createMealPlan: String { localized("nutrition.create_meal_plan") }
        static var createFirstMealPlan: String { localized("nutrition.create_first_meal_plan") }

    }

    // MARK: - Workout
    enum Workout {
        static var add: String { localized("workout.add") }
        static var edit: String { localized("workout.edit") }
        static var delete: String { localized("workout.delete") }
        static var duration: String { localized("workout.duration") }
        static var type: String { localized("workout.type") }
        static var intensity: String { localized("workout.intensity") }
        static var plans: String { localized("workout.plans") }
        static var pause: String { localized("workout.pause") }
        static var resume: String { localized("workout.resume") }
        static var finish: String { localized("workout.finish") }
        static var abandon: String { localized("workout.abandon") }
        static var noActiveSession: String { localized("workout.no_active_session") }
        static var activeWorkout: String { localized("workout.active_workout") }
        static var finishWorkout: String { localized("workout.finish_workout") }
        static var abandonWorkout: String { localized("workout.abandon_workout") }
        static var finishConfirmation: String { localized("workout.finish_confirmation") }
        static var abandonWarning: String { localized("workout.abandon_warning") }
        static var progress: String { localized("workout.progress") }

        // Workout Builder
        static var createWorkout: String { localized("workout.create_workout") }
        static var editPlan: String { localized("workout.edit_plan") }
        static var duplicatePlan: String { localized("workout.duplicate_plan") }
        static var deletePlan: String { localized("workout.delete_plan") }
        static var planTitle: String { localized("workout.plan_title") }
        static var enterPlanTitle: String { localized("workout.enter_plan_title") }
        static var addExercise: String { localized("workout.add_exercise") }
        static var exerciseName: String { localized("workout.exercise_name") }
        static var exerciseType: String { localized("workout.exercise_type") }
        static var muscleGroup: String { localized("workout.muscle_group") }
        static var targetSets: String { localized("workout.target_sets") }
        static var targetReps: String { localized("workout.target_reps") }
        static var exerciseNotes: String { localized("workout.exercise_notes") }
        static var noExercises: String { localized("workout.no_exercises") }
        static var noExercisesMessage: String { localized("workout.no_exercises_message") }
        static var savePlan: String { localized("workout.save_plan") }
        static var cancel: String { localized("workout.cancel") }
        static var aiGenerated: String { localized("workout.ai_generated") }
        static var custom: String { localized("workout.custom") }
        static var trainer: String { localized("workout.trainer") }
        static var deleteConfirmation: String { localized("workout.delete_confirmation") }
        static var deleteExercise: String { localized("workout.delete_exercise") }
        static var editExercise: String { localized("workout.edit_exercise") }
        static var exerciseDetails: String { localized("workout.exercise_details") }
        static var emptyTitle: String { localized("workout.empty_title") }
        static var emptyMessage: String { localized("workout.empty_message") }

        static func exerciseCount(_ count: Int) -> String {
            String(format: localized("workout.exercise_count"), count)
        }
    }

    // MARK: - Sleep
    enum Sleep {
        static var title: String { localized("sleep.title") }
        static var duration: String { localized("sleep.duration") }
        static var quality: String { localized("sleep.quality") }
        static var noData: String { localized("sleep.no_data") }
        static var noDataMessage: String { localized("sleep.no_data_message") }
        static var day: String { localized("sleep.day") }
        static var trends: String { localized("sleep.trends") }
        static var details: String { localized("sleep.details") }

        static func average(_ value: String) -> String {
            String(format: localized("sleep.average"), value)
        }
    }

    // MARK: - Profile
    enum Profile {
        static var title: String { localized("profile.title") }
        static var name: String { localized("profile.name") }
        static var newUser: String { localized("profile.new_user") }
        static var bodyInfo: String { localized("profile.body_info") }
        static var bodyMetrics: String { localized("profile.body_metrics") }
        static var bmi: String { localized("profile.bmi") }
        static var biologicalSex: String { localized("profile.biological_sex") }
        static var weight: String { localized("profile.weight") }
        static var height: String { localized("profile.height") }
        static var bodyMass: String { localized("profile.body_mass") }
        static var enterWeight: String { localized("profile.enter_weight") }
        static var swipeAdjust: String { localized("profile.swipe_adjust") }
        static var swipeIncrement: String { localized("profile.swipe_increment") }
        static var validWeight: String { localized("profile.valid_weight") }
        static var saveWeight: String { localized("profile.save_weight") }
        static var basicInfo: String { localized("profile.basic_info") }
        static var allergies: String { localized("profile.allergies") }
        static var bioPlaceholder: String { localized("profile.bio_placeholder") }
        static var bioOptional: String { localized("profile.bio_optional") }
        static var editMetrics: String { localized("profile.edit_metrics") }
        static var tapToSet: String { localized("profile.tap_to_set") }
        static var heightExample: String { localized("profile.height_example") }

        enum Sex {
            static var female: String { localized("profile.sex.female") }
            static var male: String { localized("profile.sex.male") }
            static var other: String { localized("profile.sex.other") }
            static var preferNotSay: String { localized("profile.sex.prefer_not_say") }
        }

        enum Settings {
            static var title: String { localized("profile.settings.title") }
            static var hideWeight: String { localized("profile.settings.hide_weight") }
            static var units: String { localized("profile.settings.units") }
            static var unitMetric: String { localized("profile.settings.unit_metric") }
            static var unitImperial: String { localized("profile.settings.unit_imperial") }
            static var language: String { localized("profile.settings.language") }

            enum Language {
                static var english: String { localized("profile.settings.language.english") }
                static var spanish: String { localized("profile.settings.language.spanish") }
                static var portuguese: String { localized("profile.settings.language.portuguese") }
                static var french: String { localized("profile.settings.language.french") }
                static var german: String { localized("profile.settings.language.german") }
            }
        }

        enum Mood {
            static var log: String { localized("profile.mood.log") }
            static var title: String { localized("profile.mood.title") }
            static var howFeeling: String { localized("profile.mood.how_feeling") }
            static var enterDetails: String { localized("profile.mood.enter_details") }
        }
    }

    // MARK: - Coach
    enum Coach {
        static var title: String { localized("coach.title") }
        static var aiInsight: String { localized("coach.ai_insight") }
        static var aiVerified: String { localized("coach.ai_verified") }
        static var connectionFailed: String { localized("coach.connection_failed") }
        static var setFirstGoal: String { localized("coach.set_first_goal") }
        static var defineGoalPrompt: String { localized("coach.define_goal_prompt") }
        static var defineGoal: String { localized("coach.define_goal") }
        static var yourCurrentGoals: String { localized("coach.your_current_goals") }
        static var feasibility: String { localized("coach.feasibility") }
        static var pending: String { localized("coach.pending") }
    }

    // MARK: - Summary
    enum Summary {
        static var title: String { localized("summary.title") }
        static var customize: String { localized("summary.customize") }
        static var tilesInstruction: String { localized("summary.tiles_instruction") }
        static var tilesTitle: String { localized("summary.tiles_title") }
        static var tilesToggle: String { localized("summary.tiles_toggle") }
        static var energy: String { localized("summary.energy") }
        static var noData: String { localized("summary.no_data") }
        static var caloriesBurned: String { localized("summary.calories_burned") }
        static var bodyMass: String { localized("summary.body_mass") }
        static var noSleepData: String { localized("summary.no_sleep_data") }
        static var stable: String { localized("summary.stable") }
        static var tapToLog: String { localized("summary.tap_to_log") }
        static var addWater: String { localized("summary.add_water") }
        static var totalAsleep: String { localized("summary.total_asleep") }
        static var active: String { localized("summary.active") }
        static var basal: String { localized("summary.basal") }
        static var target: String { localized("summary.target") }
        static var deadline: String { localized("summary.deadline") }
        static var dueToday: String { localized("summary.due_today") }
        static var activeGoals: String { localized("summary.active_goals") }
        static var setNutritionGoals: String { localized("summary.set_nutrition_goals") }
        static var kcalLabel: String { localized("summary.kcal_label") }
        static var daySingular: String { localized("summary.day_singular") }
        static var daysPlural: String { localized("summary.days_plural") }

        static func score(_ value: Int) -> String {
            String(format: localized("summary.score"), value)
        }

        static func logged(_ date: String) -> String {
            String(format: localized("summary.logged_format"), date)
        }

        static func of(_ value: String) -> String {
            String(format: localized("summary.of_format"), value)
        }

        static func percentOfGoal(_ percent: Int) -> String {
            String(format: localized("summary.percent_of_goal"), percent)
        }

        static func daysLeft(_ days: Int) -> String {
            let plural = days == 1 ? daySingular : daysPlural
            return String(format: localized("summary.days_left_format"), days, plural)
        }

        static func overdue(_ days: Int) -> String {
            let plural = days == 1 ? daySingular : daysPlural
            return String(format: localized("summary.overdue_format"), days, plural)
        }

        static func goalsCount(_ count: Int) -> String {
            let plural = count == 1 ? daySingular : daysPlural
            return String(format: localized("summary.goals_count_format"), count, plural)
        }
    }

    // MARK: - Alerts
    enum Alert {
        enum RestDay {
            static var title: String { localized("alert.rest_day.title") }
            static var message: String { localized("alert.rest_day.message") }
        }

        enum Milestone {
            static var title: String { localized("alert.milestone.title") }
            static var message: String { localized("alert.milestone.message") }
        }
    }

    // MARK: - Empty States
    enum Empty {
        static var communityFeed: String { localized("empty.community_feed") }
        static var noActiveGoals: String { localized("empty.no_active_goals") }
        static var healthKitPermissions: String { localized("empty.healthkit_permissions") }
    }

    // MARK: - Media
    enum Media {
        static var takePhoto: String { localized("media.take_photo") }
        static var choosePhoto: String { localized("media.choose_photo") }
    }

    // MARK: - Onboarding
    enum Onboarding {
        static var saveContinue: String { localized("onboarding.save_continue") }
    }

    // MARK: - Date
    enum Date {
        static var today: String { localized("date.today") }
        static var yesterday: String { localized("date.yesterday") }
        static var tomorrow: String { localized("date.tomorrow") }
        static var selectDate: String { localized("date.select_date") }
        static var day: String { localized("date.day") }
        static var week: String { localized("date.week") }
        static var month: String { localized("date.month") }
    }

    // MARK: - Units
    enum Unit {
        static var kg: String { localized("unit.kg") }
        static var cm: String { localized("unit.cm") }
        static var kcal: String { localized("unit.kcal") }
        static var g: String { localized("unit.g") }
        static var hours: String { localized("unit.hours") }
        static var na: String { localized("unit.na") }
        static var steps: String { localized("unit.steps") }
        static var ml: String { localized("unit.ml") }
        static var km: String { localized("unit.km") }
        static var days: String { localized("unit.days") }
    }

    // MARK: - Formatting
    enum Format {
        static func moreItems(_ count: Int) -> String {
            String(format: localized("format.more_items"), count)
        }

        static func naWithUnit(_ unit: String) -> String {
            String(format: localized("format.na_with_unit"), unit)
        }

        static func valueWithUnit(_ value: String, _ unit: String) -> String {
            String(format: localized("format.value_with_unit"), value, unit)
        }
    }

    // MARK: - Errors
    enum Error {
        static var generic: String { localized("error.generic") }
        static var loading: String { localized("error.loading") }
        static var network: String { localized("error.network") }
        static var saveFailed: String { localized("error.save_failed") }
        static var deleteFailed: String { localized("error.delete_failed") }
    }
}

// MARK: - Extension for easy localization of String literals

extension String {
    /// Localizes a string key
    /// - Parameter key: The localization key
    /// - Returns: The localized string
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
