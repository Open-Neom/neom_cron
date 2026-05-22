/// How a cron job can be triggered outside its schedule.
enum CronWakeMode {
  /// Timer-based wake (internal scheduler tick).
  timer,

  /// Text-triggered wake (user command or event).
  text,

  /// Manual invocation via API.
  manual,
}
