import 'package:flutter/material.dart';

abstract final class AppColors {
  static const blue = Color(0xFF003362);
  static const ink = Color(0xFF3B3B3B);
  static const black = Color(0xFF000000);
  static const yellow = Color(0xFFFBECCC);
  static const lightBlue = Color(0xFFD3E4FB);
  static const lightOrange = Color(0xFFFFA96B);
  static const darkOrange = Color(0xFFF06626);
  static const white = Color(0xFFFFFFFF);
  static const gray = Color(0xFFA1A1A1);
  static const green = Color(0xFF10B957);
  static const pink = Color(0xFFF2BCC1);
}

abstract final class AppTypography {
  static const family = 'Manrope';
  static const heading = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.black,
  );
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );
  static const badge = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: AppColors.white,
  );
  static const counter = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
}

abstract final class AppSpacing {
  static const screen = 16.0;
  static const buttonHorizontal = 22.0;
  static const buttonVertical = 14.0;
  static const group = 32.0;
  static const navigationGap = 22.0;
}

abstract final class AppRadius {
  static const nameBadge = 7.0;
  static const stageBadge = 10.0;
  static const button = 12.0;
}

abstract final class AppBorders {
  static const outlined = BorderSide(color: AppColors.ink, width: 3);
  static const nameBadge = BorderSide(color: AppColors.black, width: 3);
}

abstract final class AppShadows {
  static const nameBadge = BoxShadow(
    color: AppColors.black,
    offset: Offset(-2, 2),
  );
}
