import 'dart:io';
import 'package:flutter/material.dart';
import '../../../common/widgets/sharp_image.dart';

class CoffeeThumbSlot extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  const CoffeeThumbSlot({super.key, required this.label, required this.file, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Colors.white24),
    );
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 0.75; // 4:3 oran
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  width: w,
                  height: h,
                  decoration: ShapeDecoration(shape: border),
                  child: file == null
                      ? const Center(child: Icon(Icons.add_a_photo, color: Colors.white70))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SharpImage.file(
                            file!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }
}
