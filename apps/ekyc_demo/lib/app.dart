import 'package:ekyc_demo/core/privacy_shield.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/ui/kyc_flow_page.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class EkycApp extends StatelessWidget {
  const EkycApp({
    required this.loadServices,
    this.cameraAvailable = true,
    this.locale,
    super.key,
  });

  final KycServicesLoader loadServices;
  final bool cameraAvailable;

  /// Overrides the device locale (tests, screenshots).
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00696B);
    return BlocProvider(
      create: (_) => KycFlowCubit(
        loadServices,
        photographDocument: cameraAvailable,
      ),
      child: MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(colorSchemeSeed: seed),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
        ),
        builder: (context, child) => PrivacyShield(
          label: AppLocalizations.of(context).privacyShield,
          child: child ?? const SizedBox.shrink(),
        ),
        home: KycFlowPage(cameraAvailable: cameraAvailable),
      ),
    );
  }
}
