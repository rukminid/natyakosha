import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../../core/theme/app_theme.dart';
import '../../redux/state/app_state.dart';

/// Wraps the whole app; shows a slim bar while the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, bool>(
      converter: (store) => store.state.isOnline,
      distinct: true,
      builder: (context, isOnline) => Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: isOnline
                ? const SizedBox(width: double.infinity)
                : Material(
                    color: AppColors.ink,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "You're offline. Changes will sync when you're back online.",
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            // When the banner is visible it already consumed the top inset.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: !isOnline,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
