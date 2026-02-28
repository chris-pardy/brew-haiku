import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  final bool returnAfterAuth;

  const SignInScreen({super.key, this.returnAfterAuth = false});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _handleController = TextEditingController();
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final auth = ref.read(authProvider);
      if (auth.lastHandle != null) {
        _handleController.text = auth.lastHandle!;
      }
    }
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  void _signIn() {
    final handle = _handleController.text.trim();
    if (handle.isEmpty) return;
    ref.read(authProvider.notifier).signIn(handle);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // If authenticated and showing settings, show account info
    if (auth.isAuthenticated && !widget.returnAfterAuth) {
      return GradientScaffold(
        appBar: AppBar(
          title: Text(S.settings, style: BrewTypography.heading),
        ),
        body: Padding(
          padding: const EdgeInsets.all(BrewSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: BrewSpacing.xl),
              Text(
                '@${auth.session!.handle}',
                style: BrewTypography.heading,
              ),
              const SizedBox(height: BrewSpacing.sm),
              Text(
                auth.session!.did,
                style: BrewTypography.bodySmall,
              ),
              const SizedBox(height: BrewSpacing.xl),
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).signOut();
                },
                child: Text(
                  S.signOut,
                  style: BrewTypography.label.copyWith(
                    color: BrewColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GradientScaffold(
      appBar: AppBar(
        title: Text(S.signInTitle, style: BrewTypography.heading),
      ),
      body: Padding(
        padding: const EdgeInsets.all(BrewSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              'Brew Haiku',
              style: BrewTypography.heading.copyWith(fontSize: 32),
            ),
            const SizedBox(height: BrewSpacing.xxl),
            TextField(
              controller: _handleController,
              style: BrewTypography.body,
              autocorrect: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _signIn(),
              decoration: InputDecoration(
                hintText: S.handleHint,
                hintStyle: BrewTypography.body.copyWith(
                  color: BrewColors.subtle,
                ),
                prefixIcon: const Icon(Icons.alternate_email,
                    color: BrewColors.subtle),
              ),
            ),
            const SizedBox(height: BrewSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.signingIn ? null : _signIn,
                child: auth.signingIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrewColors.warmCream,
                        ),
                      )
                    : Text(S.signInButton, style: BrewTypography.button),
              ),
            ),
            if (auth.error != null) ...[
              const SizedBox(height: BrewSpacing.base),
              Text(
                auth.error!,
                style: BrewTypography.bodySmall.copyWith(
                  color: BrewColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
