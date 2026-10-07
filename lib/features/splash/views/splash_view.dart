import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../view_models/splash_view_model.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, SplashViewModel>(
      converter: SplashViewModel.fromStore,
      distinct: true,
      // Kick off session restore once; the router redirects when it finishes.
      onInitialBuild: (vm) => vm.restore(),
      builder: (context, vm) => const Scaffold(
        backgroundColor: AppColors.maroon,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.self_improvement, size: 72, color: AppColors.gold),
              SizedBox(height: 16),
              Text(
                'Natyakosha',
                style: TextStyle(
                  color: AppColors.ivory,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Every class, every stage, every step',
                style: TextStyle(color: AppColors.gold, fontSize: 14),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
