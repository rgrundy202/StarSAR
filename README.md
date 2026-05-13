# StarSAR
## A synthetic aperture radar simulation using Starlink satellite downlink signals as Illuminators of Opportunity (IoO)

This project was created as a final project for the EC 707 Radar Remote Sensing class. Drawing on existing literature from Humphreys et al. at UT Austin, this program simulates the downlink signal of the Starlink satellite. There is an existing simulation program produced by Komodromos et al. also at UT Austin. I believe our approaches differ slightly however I still need to look into possible improvements.
The downlink signal is then used in a passive radar simulation. The signal is mixed and propagated using free space propagation, before being reflected by a target. This point target has a constant RCS even as the geometry changes with a moving satellite. The antennas in this simulation are isotropic. The simulation generates a direct path signal and a reflected signal. The reflected signal in this simulation does not contain the direct path even though the geometry and antenna allows it. There is an option for it in the code, however direct path mitigation was outside of the scope of this project. 
The reflected and direct path signal are the fed into the analysis script, which uses matched filtering to get a differential range. The position of the sattelite is then used in combination with this range to back project a synthetic aperture image.

 ## Notes and Future Improvements
Currently there are several issues with this simulation that need to be addressed. The clipping method used to solve the PAPR problem in the OFDM encoding causes ambiguities in the range before the known ambiguities from the cyclic prefix in the OFDM. The doppler shift between the target and receiver is also not addressed. This does cause a diminished return from the matched filtering however image formation is still possible, the SNR from the link budget just doesn't line up. 
Ideally in the future this simulation would be adapted for full landscape SAR similar to the experimental work done by Gomez del-Hoyo et al. but the computational power required for that using the current method makes that unrealistic. 


Further information can be found in the paper writeup and the presentation below.

## References

T. E. Humphreys, P. A. Iannucci, Z. M. Komodromos, and
A. M. Graff, “Signal structure of the starlink ku-band downlink,”
IEEE Transactions on Aerospace and Electronic Systems, vol. 59,
no. 5, pp. 6016–6030, 2023.

P. Gomez-del Hoyo and P. Samczynski, “Starlink-based passive
radar for earth’s surface imaging: First experimental results,”
IEEE Journal of Selected Topics in Applied Earth Observations
and Remote Sensing, vol. 17, pp. 13949–13965, 2024.

Z. M. Komosdromos, W. Qin, and T. E. Humphreys,
"Signal Simulator for Starlink Ku-Band Downlink"
ION GNSS + 2023 Preprint
