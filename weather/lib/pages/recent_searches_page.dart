import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/recent_searches_provider.dart';
import 'weather_page.dart';

class RecentSearchesPage extends StatelessWidget {
  const RecentSearchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          "Recent Searches",
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Consumer<RecentSearchesProvider>(
        builder: (context, provider, child) {
          final history = provider.history;
          
          if (history.isEmpty) {
            return Center(child: Text("No recent searches", style: tt.bodyLarge));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final timeDt = DateTime.tryParse(item.searchedAt + (item.searchedAt.contains('Z') || item.searchedAt.contains('+') ? '' : 'Z'))?.toLocal();
              final timeStr = timeDt != null 
                  ? "${timeDt.hour.toString().padLeft(2, '0')}:${timeDt.minute.toString().padLeft(2, '0')}"
                  : "";

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
                ),
                elevation: 0,
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.city.isNotEmpty ? item.city[0].toUpperCase() + item.city.substring(1) : "Unknown",
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "${item.temperature.toStringAsFixed(1)}°C • ${item.description}",
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: cs.primary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WeatherPage(city: item.city),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
