static void my_application_startup(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Set up error handling for GTK
  g_set_printerr_handler([](const gchar* string) {
    // Filter out the specific GLib-GObject warning
    if (!g_str_has_prefix(string, "GLib-GObject-CRITICAL **")) {
      g_printerr("%s", string);
    }
  });

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  // Ensure proper cleanup
  gtk_widget_destroy(GTK_WIDGET(gtk_application_get_active_window(GTK_APPLICATION(application))));
  
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
} 