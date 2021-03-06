; docformat = 'rst'
;
; NAME:
;       mms_fg_create_l2
;
;*****************************************************************************************
;   Copyright (c) 2015, University of New Hampshire                                      ;
;   All rights reserved.                                                                 ;
;                                                                                        ;
;   Redistribution and use in source and binary forms, with or without modification,     ;
;   are permitted provided that the following conditions are met:                        ;
;                                                                                        ;
;       * Redistributions of source code must retain the above copyright notice,         ;
;         this list of conditions and the following disclaimer.                          ;
;       * Redistributions in binary form must reproduce the above copyright notice,      ;
;         this list of conditions and the following disclaimer in the documentation      ;
;         and/or other materials provided with the distribution.                         ;
;       * Neither the name of the University of New Hampshire nor the names of its       ;
;         contributors may  be used to endorse or promote products derived from this     ;
;         software without specific prior written permission.                            ;
;                                                                                        ;
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY  ;
;   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES ;
;   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT  ;
;   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,       ;
;   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED ;
;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR   ;
;   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     ;
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN   ;
;   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  ;
;   DAMAGE.                                                                              ;
;*****************************************************************************************
;
; PURPOSE:
;+
;   Read AFG and DFG level 1A data and turn it into level 2 data.
;   L2 implies calibrated data in despun spacecraft reference frame (no VxB removal)
;   and in the GSE coordinate system.
;
; :Categories:
;   MMS, DFG, AFG
;
; :Params:
;       FILES:          in, required, type=string/strarr
;                       Name(s) of the AFG or DFG L1A file(s) to read.
;       HICAL_FILES:    in, required, type=string/strarr
;                       Name(s) of the AFG or DFG hi-range calibration file(s) to read.
;       LOCAL_FILES:    in, required, type=string/strarr
;                       Name(s) of the AFG or DFG lo-range calibration file(s) to read.
;
; :Keywords:
;       ATTITUDE_DIR:   in, optional, type=string, default=pwd
;                       Directory in which to find FDOA definitive attitude data.
;       DMPA:           in, optional, type=boolean, default=0
;                       If set, data in DMPA will be included in `FG_GSE`
;       GSE:            in, optional, type=boolean, default=1
;                       If set, data in GSE will be included in `FG_GSE`
;       SUNPULSE_DIR:   in, optional, type=string, default=pwd
;                       Directory in which to find HK 0X101 sunpulse data.
;       TSTART:         in, optional, type=string
;                       Start time of the data interval to read, as an ISO-8601 string.
;       TEND:           in, optional, type=string
;                       End time of the data interval to read, as an ISO-8601 string.
;       _REF_EXTRA:     in, optional, type=string, default=pwd
;                       Any keyword accepted by mms_fg_bcs is also accepted via keyword
;                           inheritance.
;
; :Returns:
;       FG_GSE:         Fluxgate magnetic field data structure. Possible fields include::
;                           'epoch'        - TT2000 epoch times for 'b_123'
;                           'epoch_stat'   - TT2000 epoch times for 'range' and 'sample_rate'
;                           'b_123'        - 4xN (Bx, By, Bz, |B|) in 123 coordinates
;                           'b_omb'        - 4xN (Bx, By, Bz, |B|) in OMB coordinates
;                           'b_smpa'       - 4xN (Bx, By, Bz, |B|) in SMPA coordinates
;                           'b_bcs'        - 4xN (Bx, By, Bz, |B|) in BCS coordinates
;                           'b_dmpa'       - 4xN (Bx, By, Bz, |B|) in DMPA coordinates
;                           'b_gse'        - 4xN (Bx, By, Bz, |B|) in GSE coordinates
;                           'range'        - Instrument range flag (1=hi, 0=lo)
;                           'sample_rate'  - sampling rate
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 348
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@unh.edu
;
; :History:
;   Modification History::
;       2015/05/04  -   Written by Matthew Argall
;       2015/05/18  -   Require file names instead of search for files. TSTART and TEND
;                           are keywords, not parameters. - MRA
;       2015/06/22  -   renamed from mms_fg_gse to mms_fg_create_l2. - MRA
;-
function mms_fg_create_l2, files, hiCal_file, loCal_file, tstart, tend, $
ATTITUDE=attitude, $
CS_SMPA=cs_smpa, $
CS_DMPA=cs_dmpa, $
CS_GSE=cs_gse, $
SUNPULSE=sunpulse, $
_REF_EXTRA=extra
	compile_opt idl2
	on_error, 2
	
	;Defaults
	cs_smpa = keyword_set(cs_smpa)
	cs_dmpa = keyword_set(cs_dmpa)
	cs_gse  = n_elements(cs_gse) eq 0 ? 0 : keyword_set(cs_gse)
	
;-----------------------------------------------------
; Get the data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Read data
	fg_bcs = mms_fg_create_l1b(files, hiCal_file, loCal_file, /CS_SMPA, $
	                           TSTART        = tstart, $
	                           TEND          = tend, $
	                           _STRICT_EXTRA = extra)

;-----------------------------------------------------
; Despin \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;
	; Assume the principle axis of inertia (z-MPA)
	; is the same as the angular momentum vector (L)
	;

	;Despin using definitive attitude
	if n_elements(attitude) gt 0 then begin
		smpa2dmpa_gd12 = mms_fdoa_xdespin(attitude, fg_bcs.epoch, 'L')

	;Despin using sun pulse times.
	endif else if n_elements(sunpulse) gt 0 then begin
		smpa2dmpa = mms_dss_xdespin( sunpulse, fg_bcs.epoch )
	endif else begin
		message, 'Either ATTITUDE or SUNPULSE must be given.'
	endelse

	;Transform
	b_dmpa = mrvector_rotate( smpa2dmpa, fg_bcs.b_smpa )


;-----------------------------------------------------
; Rotate to GSE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if n_elements(attitude) gt 0 then begin
		message, 'Rotate to GSE not implemented yet.'
		
		;dmpa2gei
		
		;CXForm
		b_gse = cxform(b_dmpa, 'GEI', 'GSE', sse)
	endif else begin
		message, 'No attitude data. Cannot rotate to GSE', /INFORMATIONAL
		b_gse = !Null
	endelse

;-----------------------------------------------------
; Return Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Copy the data structure
	fg_gse = temporary(fg_bcs)
	if ~cs_smpa then fg_gse = remove_tags(fg_gse, 'b_smpa')
	if  cs_dmpa then fg_gse = create_struct(fg_gse, 'b_dmpa', b_dmpa)
	if  cs_gse  then fg_gse = create_struct(fg_gse, 'b_gse',  b_gse)

	return, fg_gse
end