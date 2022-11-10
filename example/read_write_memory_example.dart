// ignore_for_file: non_constant_identifier_names

import 'package:read_write_memory/read_write_memory.dart';

void main() {
  ReadWriteMemory rw = ReadWriteMemory();
  Process process = rw.getProcessByName('ac_client');
  process.open();

  Module ac_client = process.moduleFromName('ac_client.exe');

  int localPlayer = ac_client.lpBaseOfDll + 0x0017E0A8;

  int m_Health = process.getPointer(localPlayer, offsets: [0xEC]);
  int m_Vest = process.getPointer(localPlayer, offsets: [0xF0]);
  int m_Ammo = process.getPointer(localPlayer, offsets: [0x140]);
  int m_AmmoMags = process.getPointer(localPlayer, offsets: [0x11C]);
  int m_SecAmmo = process.getPointer(localPlayer, offsets: [0x12C]);
  int m_SecAmmoMags = process.getPointer(localPlayer, offsets: [0x108]);
  int m_Grenades = process.getPointer(localPlayer, offsets: [0x144]);

  print(process);
  print(ac_client);
  print('Health: ${process.readInt(m_Health)}');
  print('Vest: ${process.readInt(m_Vest)}');
  print('Ammo: ${process.readInt(m_Ammo)}/${process.readInt(m_AmmoMags)}');
  print(
      'Sec Ammo: ${process.readInt(m_SecAmmo)}/${process.readInt(m_SecAmmoMags)}');
  print('Grenades: ${process.readInt(m_Grenades)}');

  process.writeInt(m_Health, 1000);
  process.writeInt(m_Vest, 1000);
  process.writeInt(m_Ammo, 20);
  process.writeInt(m_AmmoMags, 240);
  process.writeInt(m_SecAmmo, 10);
  process.writeInt(m_SecAmmoMags, 100);
  process.writeInt(m_Grenades, 20);
}
