# To Do

## Features
Mark sub tasks as complete [X] when finished.

### CSV Export
Description: Allow users to export their data as a CSV file.
Sub-Tasks:
- Add export data button to Settings [X]
- Create a sheet that opens when export data is clicked that allows the user to choose which categories/symptoms to include in the csv file (or all). [X]
- Create a DataManager class. This should have the @Observable macro and should be a singleton. This class will contain the logic for exporting data. [X]
- Write the export function. Turn the data the user wants into the proper csv file. Allow them to export to files or wherever else is a valid destination. [X] 

### Weather Tracking
Description: This feature will use automatic weather data is an extra data point for the logs. The user will not have to configure anything, it will automatically collect when the user saves a log.
- Add a weather field to the DailyLog model (and add a migration to add this column for the database schema). The data should just be a string like "Cloudy 70" or "Sunny 45". This should be an optional field in case the user doesnt want to use weather tracking. [X]
- In UserSettings, add a Weather toggle option to allow the user to turn on or off the weather tracking. [X]
- During the Onboarding flow (or when the app launches if onboarding is already complete), ask the user for permission to use their location for weather data. [X]
- When a log gets saved for Today (not for other past dates), use Apples WeatherKit to collect the current weather data and add it to the DailyLog on save. [X]
- In the History view (the calendar), add a weather data display to the sheet that shows information about a log for the day that was clicked. [ ]
