import 'package:flutter/material.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/mapa_cercanos.dart';

/// Mapa falso sin plataforma ni red que expone pines accesibles con Semantics.
Widget mapaFalso(
  BuildContext context,
  DatosMapaCercanos datos, {
  void Function(DatosMapaCercanos)? alRecibir,
}) {
  alRecibir?.call(datos);
  return GestureDetector(
    key: const Key('mapa-falso'),
    behavior: HitTestBehavior.opaque,
    onTap: datos.onTocarMapa,
    child: ColoredBox(
      color: const Color(0xFFE5E7EB),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                label: MensajesNegocios.tuUbicacion,
                child: const SizedBox.square(
                  key: Key('punto-cliente'),
                  dimension: 16,
                ),
              ),
              for (final pin in datos.pines)
                Semantics(
                  button: true,
                  selected: pin.seleccionado,
                  label: pin.descripcionSemantica,
                  child: Material(
                    color: pin.seleccionado
                        ? ColoresServia.morado
                        : const Color(0xFF0F0F0F),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      key: Key('pin-${pin.id}'),
                      customBorder: const StadiumBorder(),
                      onTap: () => datos.onSeleccionarPin(pin.id),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: ExcludeSemantics(
                              child: Text(
                                pin.etiqueta,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
