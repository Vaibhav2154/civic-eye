import 'dart:ui';

import 'package:flutter/material.dart';

const textColor = Color(0xFFe2f2fd);
const backgroundColor = Color(0xFF090e1b);
const primaryColor = Color(0xFF1e3b8a);
const primaryFgColor = Color(0xFFe2f2fd);
const secondaryColor = Color(0xFF80b0ff);
const secondaryFgColor = Color(0xFF090e1b);
const accentColor = Color(0xFFb1bdc4);
const accentFgColor = Color(0xFF090e1b);

const colorScheme = ColorScheme(
  brightness: Brightness.dark,
  background: backgroundColor,
  onBackground: textColor,
  primary: primaryColor,
  onPrimary: primaryFgColor,
  secondary: secondaryColor,
  onSecondary: secondaryFgColor,
  tertiary: accentColor,
  onTertiary: accentFgColor,
  surface: backgroundColor,
  onSurface: textColor,
  error: Brightness.dark == Brightness.light ? Color(0xffB3261E) : Color(0xffF2B8B5),
  onError: Brightness.dark == Brightness.light ? Color(0xffFFFFFF) : Color(0xff601410),
);